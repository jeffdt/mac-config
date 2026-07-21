#!/usr/bin/env node
import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, statSync, writeFileSync, chmodSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join, relative, sep } from "node:path";
import { isMap, parseDocument } from "yaml";

const HOME = homedir();
const ROOT_DIR = join(HOME, ".agents");
const SOURCE_SKILLS_DIR = join(ROOT_DIR, "skills");
const SOURCE_AGENTS_DIR = join(ROOT_DIR, "agents");
const SOURCE_AGENT_PROMPTS_DIR = join(ROOT_DIR, "agent-prompts");
const SOURCE_SCRIPTS_DIR = join(ROOT_DIR, "scripts");

const CLAUDE_SKILLS_DIR = join(HOME, ".claude", "skills");
const CLAUDE_AGENTS_DIR = join(HOME, ".claude", "agents");
const CLAUDE_AGENT_PROMPTS_DIR = join(HOME, ".claude", "agent-prompts");
const CLAUDE_SCRIPTS_DIR = join(HOME, ".claude", "scripts");
const PI_GENERATED_AGENTS_DIR = join(HOME, ".pi", "agent", "agents", "generated");

const MANIFEST_PATH = join(ROOT_DIR, ".publish-manifest.json");
const LOCK_DIR = join(ROOT_DIR, ".publish.lock");
const LOCK_STALE_MS = 300_000;

const TOOL_MAP = {
  Bash: ["bash"],
  Read: ["read"],
  Grep: ["grep"],
  Glob: ["find"],
  WebFetch: ["fetch_content"],
  Task: ["subagent"],
};

const KNOWN_PI_TOOLS = new Set([
  "bash",
  "read",
  "grep",
  "find",
  "ls",
  "edit",
  "write",
  "mcp",
  "fetch_content",
  "web_search",
  "code_search",
  "subagent",
  "intercom",
]);

const COPY_EXCLUDED_NAMES = new Set([".DS_Store", "__pycache__", ".pytest_cache", "node_modules", ".git"]);
const COPY_EXCLUDED_SUFFIXES = [".pyc", ".tmp"];

/** Returns whether an unknown caught value is a Node.js filesystem error with the given code. */
function isNodeError(error, code) {
  return typeof error === "object" && error !== null && "code" in error && error.code === code;
}

/** Formats an error for concise CLI output. */
function formatError(error) {
  return error instanceof Error ? error.message : String(error);
}

/** Converts an absolute path under the home directory to a stable display path. */
function displayPath(path) {
  return path.startsWith(`${HOME}${sep}`) ? `~${path.slice(HOME.length)}` : path;
}

/** Reads JSON from disk, returning a fallback when the file is absent or invalid. */
function readJson(path, fallback) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    if (isNodeError(error, "ENOENT")) return fallback;
    return fallback;
  }
}

/** Writes a file atomically by writing a sibling temp file and renaming it into place. */
function writeFileAtomic(path, data, mode = 0o644, dryRun = false) {
  if (dryRun) return;
  mkdirSync(dirname(path), { recursive: true });
  const tempPath = join(dirname(path), `.${basename(path)}.${process.pid}.${Date.now()}.tmp`);
  try {
    writeFileSync(tempPath, data, { mode });
    chmodSync(tempPath, mode);
    renameSync(tempPath, path);
  } catch (error) {
    rmSync(tempPath, { force: true });
    throw error;
  }
}

/** Copies a file atomically while preserving its executable mode. */
function copyFileAtomic(sourcePath, targetPath, dryRun = false) {
  if (dryRun) return;
  mkdirSync(dirname(targetPath), { recursive: true });
  const tempPath = join(dirname(targetPath), `.${basename(targetPath)}.${process.pid}.${Date.now()}.tmp`);
  try {
    copyFileSync(sourcePath, tempPath);
    chmodSync(tempPath, statSync(sourcePath).mode & 0o777);
    renameSync(tempPath, targetPath);
  } catch (error) {
    rmSync(tempPath, { force: true });
    throw error;
  }
}

/** Acquires the publisher lock, removing abandoned locks older than the stale threshold. */
function acquireLock() {
  for (;;) {
    try {
      mkdirSync(LOCK_DIR);
      writeFileSync(join(LOCK_DIR, "owner"), `${process.pid}\n`);
      return;
    } catch (error) {
      if (!isNodeError(error, "EEXIST")) throw error;
      try {
        if (Date.now() - statSync(LOCK_DIR).mtimeMs <= LOCK_STALE_MS) {
          throw new Error(`another publish is already running (${displayPath(LOCK_DIR)})`);
        }
      } catch (statError) {
        if (!isNodeError(statError, "ENOENT")) throw statError;
      }
      rmSync(LOCK_DIR, { recursive: true, force: true });
    }
  }
}

/** Releases the publisher lock when this process owns it. */
function releaseLock() {
  try {
    const owner = readFileSync(join(LOCK_DIR, "owner"), "utf8").trim();
    if (owner !== String(process.pid)) return;
  } catch (error) {
    if (isNodeError(error, "ENOENT")) return;
    throw error;
  }
  rmSync(LOCK_DIR, { recursive: true, force: true });
}

/** Walks a directory recursively, skipping generated and cache files. */
function walkFiles(rootDir) {
  if (!existsSync(rootDir)) return [];

  const files = [];
  const visit = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (COPY_EXCLUDED_NAMES.has(entry.name)) continue;
      if (COPY_EXCLUDED_SUFFIXES.some((suffix) => entry.name.endsWith(suffix))) continue;

      const path = join(dir, entry.name);
      if (entry.isDirectory()) {
        visit(path);
      } else if (entry.isFile()) {
        files.push(path);
      }
    }
  };

  visit(rootDir);
  return files.sort();
}

/** Parses markdown frontmatter without depending on a YAML parser. */
function parseMarkdown(raw) {
  if (!raw.startsWith("---")) return { frontmatterLines: [], body: raw, hasFrontmatter: false };

  const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/);
  if (!match) return { frontmatterLines: [], body: raw, hasFrontmatter: false };

  return {
    frontmatterLines: match[1].split(/\r?\n/),
    body: raw.slice(match[0].length),
    hasFrontmatter: true,
  };
}

/** Parses an entry's YAML frontmatter and adds validation errors when it is unusable. */
function parseFrontmatter(sourcePath, raw, errors) {
  const parsed = parseMarkdown(raw);
  const path = displayPath(sourcePath);

  if (!parsed.hasFrontmatter) {
    errors.push(`${path} is missing YAML frontmatter`);
    return undefined;
  }

  const document = parseDocument(parsed.frontmatterLines.join("\n"));
  if (document.errors.length > 0) {
    for (const error of document.errors) {
      errors.push(`${path} has invalid YAML frontmatter: ${error.message}`);
    }
    return undefined;
  }

  if (!isMap(document.contents)) {
    errors.push(`${path} frontmatter must be a YAML mapping`);
    return undefined;
  }

  return document.toJS();
}

/** Removes matching single or double quotes around a scalar frontmatter value. */
function stripMatchingQuotes(value) {
  const trimmed = value.trim();
  if ((trimmed.startsWith('"') && trimmed.endsWith('"')) || (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

/** Reads a scalar frontmatter key from parsed frontmatter lines. */
function frontmatterValue(lines, key) {
  const prefix = `${key}:`;
  const line = lines.find((candidate) => candidate.trimStart().startsWith(prefix));
  if (!line) return undefined;
  return stripMatchingQuotes(line.slice(line.indexOf(":") + 1));
}

/** Inserts a generated-file notice after frontmatter so markdown remains valid. */
function withGeneratedNotice(raw, sourcePath) {
  const notice = [
    `> Generated from ${displayPath(sourcePath)}. Do not edit this copy directly.`,
    "> Edit the source under ~/.agents, then run agents-publish.",
    "",
  ].join("\n");

  const parsed = parseMarkdown(raw);
  if (!parsed.hasFrontmatter) return `${notice}${raw}`;

  return ["---", ...parsed.frontmatterLines, "---", "", notice, parsed.body.trimStart()].join("\n");
}

/** Converts Claude or Agent Skills tool names to Pi tool names. */
function normalizeTools(value) {
  const requested = (value ?? "Bash, Read, Grep, Glob")
    .split(",")
    .map((tool) => tool.trim())
    .filter(Boolean);

  const mapped = [];
  for (const tool of requested) {
    if (tool.startsWith("mcp__")) {
      mapped.push("mcp");
    } else if (TOOL_MAP[tool]) {
      mapped.push(...TOOL_MAP[tool]);
    } else if (KNOWN_PI_TOOLS.has(tool)) {
      mapped.push(tool);
    }
  }

  for (const fallback of ["read", "bash", "grep", "find", "ls", "intercom"]) {
    if (!mapped.includes(fallback)) mapped.push(fallback);
  }

  return [...new Set(mapped)];
}

/** Keeps source frontmatter lines that are safe for Pi agent definitions. */
function retainedPiFrontmatter(lines) {
  const dropped = new Set(["name", "package", "tools", "model", "color"]);
  const retained = [];
  let droppingMultiline = false;

  for (const line of lines) {
    const keyMatch = line.match(/^([A-Za-z0-9_-]+):/);
    if (keyMatch) {
      droppingMultiline = dropped.has(keyMatch[1]);
      if (!droppingMultiline) retained.push(line);
      continue;
    }

    if (!droppingMultiline) retained.push(line);
  }

  return retained.filter((line) => line.trim());
}

/** Derives a readable description from the first markdown heading when frontmatter lacks one. */
function firstHeading(body, fallback) {
  const heading = body.split(/\r?\n/).find((line) => line.startsWith("# "));
  return heading ? heading.replace(/^#\s+/, "").trim() : fallback;
}

/** Produces the Pi compatibility preamble for a converted Claude-style agent. */
function compatibilityPreamble(sourcePath, requestedTools) {
  return [
    `> Generated from ${displayPath(sourcePath)}. Do not edit this copy directly.`,
    "> Edit the source under ~/.agents, then run agents-publish.",
    "",
    "## Pi compatibility notes",
    "",
    `- Original Claude tools: ${requestedTools ?? "not specified"}. This generated Pi agent maps them to available Pi tools.`,
    "- If the source prompt names Claude-only tools such as `Task`, `WebFetch`, or `mcp__...`, use the mapped Pi tools instead: `subagent`, `fetch_content`, or `mcp` when available.",
    "- Prefer `gh`, `linear`, and existing repository scripts when a Claude MCP tool is unavailable in the child session.",
    "",
  ].join("\n");
}

/** Removes characters Jeff does not want in generated Pi prompt text. */
function sanitizeGeneratedText(text) {
  return text.replace(/\u2014/g, "-");
}

/** Renders a source agent into a Pi subagent markdown file. */
function renderPiAgent(sourcePath, options = {}) {
  const raw = readFileSync(sourcePath, "utf8");
  const parsed = parseMarkdown(raw);
  const generatedName = basename(sourcePath, ".md");
  const sourceName = options.packageName ? `${options.packageName}-${generatedName}` : frontmatterValue(parsed.frontmatterLines, "name") ?? generatedName;
  const requestedTools = frontmatterValue(parsed.frontmatterLines, "tools");
  const tools = normalizeTools(requestedTools);
  const body = parsed.body.trimStart();
  const retained = retainedPiFrontmatter(parsed.frontmatterLines);
  const hasDescription = retained.some((line) => line.trimStart().startsWith("description:"));
  const frontmatter = [
    `name: ${sourceName}`,
    ...(hasDescription ? [] : [`description: ${firstHeading(body, sourceName)}`]),
    ...retained,
    `tools: ${tools.join(", ")}`,
    "systemPromptMode: replace",
    "inheritProjectContext: true",
    "inheritSkills: true",
  ];

  return sanitizeGeneratedText([
    "---",
    ...frontmatter,
    "---",
    "",
    compatibilityPreamble(sourcePath, requestedTools),
    body,
  ].join("\n").trimEnd() + "\n");
}

/** Returns the skill package name for a nested skill agent path. */
function skillPackageFromAgentPath(path) {
  const rel = relative(SOURCE_SKILLS_DIR, path);
  if (rel.startsWith("..") || rel === path) return undefined;
  const parts = rel.split(sep);
  if (parts.length < 3 || parts[1] !== "agents") return undefined;
  return parts[0];
}

/** Publishes a source file and records the expected target path. */
function publishTextFile(sourcePath, targetPath, text, result, dryRun) {
  result.files.push(targetPath);
  result.written += 1;
  writeFileAtomic(targetPath, text, statSync(sourcePath).mode & 0o777, dryRun);
}

/** Publishes a directory tree with optional SKILL.md generated notices. */
function publishTree(sourceDir, targetDir, result, options) {
  for (const sourcePath of walkFiles(sourceDir)) {
    const targetPath = join(targetDir, relative(sourceDir, sourcePath));
    result.files.push(targetPath);
    result.written += 1;

    if (options.noticeForSkillMarkdown && basename(sourcePath) === "SKILL.md") {
      publishTextFile(sourcePath, targetPath, withGeneratedNotice(readFileSync(sourcePath, "utf8"), sourcePath), { files: [], written: 0 }, options.dryRun);
    } else {
      copyFileAtomic(sourcePath, targetPath, options.dryRun);
    }
  }
}

/** Removes files this publisher owned in a previous manifest but no longer produces. */
function pruneStaleFiles(previousManifest, nextManifest, dryRun) {
  const pruned = [];
  const previousTargets = previousManifest.targets ?? {};
  const nextTargets = nextManifest.targets ?? {};

  for (const [targetName, previousFiles] of Object.entries(previousTargets)) {
    const nextFiles = new Set(nextTargets[targetName] ?? []);
    for (const file of previousFiles ?? []) {
      if (nextFiles.has(file) || !existsSync(file)) continue;
      pruned.push(file);
      if (!dryRun) rmSync(file, { force: true });
    }
  }

  return pruned;
}

/** Validates a canonical skill or agent entry's YAML frontmatter. */
function validateEntry(sourcePath, errors) {
  const frontmatter = parseFrontmatter(sourcePath, readFileSync(sourcePath, "utf8"), errors);
  if (!frontmatter) return;

  for (const key of ["name", "description"]) {
    if (typeof frontmatter[key] !== "string" || !frontmatter[key].trim()) {
      errors.push(`${displayPath(sourcePath)} is missing frontmatter ${key}`);
    }
  }
}

/** Validates canonical skill and agent entry files before publishing. */
function validateSources() {
  const errors = [];

  for (const skillFile of walkFiles(SOURCE_SKILLS_DIR).filter((path) => basename(path) === "SKILL.md")) {
    validateEntry(skillFile, errors);
  }

  for (const agentFile of walkFiles(SOURCE_AGENTS_DIR).filter((path) => path.endsWith(".md"))) {
    validateEntry(agentFile, errors);
  }

  return errors;
}

/** Publishes all canonical resources to Claude and Pi target directories. */
function publishAll(options) {
  const manifest = {
    version: 1,
    generatedAt: new Date().toISOString(),
    sourceRoot: ROOT_DIR,
    targets: {},
  };
  const counts = {};

  const claudeSkills = { files: [], written: 0 };
  publishTree(SOURCE_SKILLS_DIR, CLAUDE_SKILLS_DIR, claudeSkills, { dryRun: options.dryRun, noticeForSkillMarkdown: true });
  manifest.targets.claudeSkills = claudeSkills.files;
  counts.claudeSkills = claudeSkills.written;

  const claudeAgents = { files: [], written: 0 };
  for (const sourcePath of walkFiles(SOURCE_AGENTS_DIR).filter((path) => path.endsWith(".md"))) {
    publishTextFile(sourcePath, join(CLAUDE_AGENTS_DIR, basename(sourcePath)), withGeneratedNotice(readFileSync(sourcePath, "utf8"), sourcePath), claudeAgents, options.dryRun);
  }
  manifest.targets.claudeAgents = claudeAgents.files;
  counts.claudeAgents = claudeAgents.written;

  const claudeAgentPrompts = { files: [], written: 0 };
  publishTree(SOURCE_AGENT_PROMPTS_DIR, CLAUDE_AGENT_PROMPTS_DIR, claudeAgentPrompts, { dryRun: options.dryRun });
  manifest.targets.claudeAgentPrompts = claudeAgentPrompts.files;
  counts.claudeAgentPrompts = claudeAgentPrompts.written;

  const claudeScripts = { files: [], written: 0 };
  publishTree(SOURCE_SCRIPTS_DIR, CLAUDE_SCRIPTS_DIR, claudeScripts, { dryRun: options.dryRun });
  manifest.targets.claudeScripts = claudeScripts.files;
  counts.claudeScripts = claudeScripts.written;

  const piAgents = { files: [], written: 0 };
  for (const sourcePath of walkFiles(SOURCE_AGENTS_DIR).filter((path) => path.endsWith(".md"))) {
    publishTextFile(sourcePath, join(PI_GENERATED_AGENTS_DIR, "agents", basename(sourcePath)), renderPiAgent(sourcePath), piAgents, options.dryRun);
  }
  for (const sourcePath of walkFiles(SOURCE_SKILLS_DIR).filter((path) => path.endsWith(".md") && relative(SOURCE_SKILLS_DIR, path).split(sep).includes("agents"))) {
    const packageName = skillPackageFromAgentPath(sourcePath) ?? "unpackaged";
    publishTextFile(sourcePath, join(PI_GENERATED_AGENTS_DIR, "skill-agents", packageName, basename(sourcePath)), renderPiAgent(sourcePath, { packageName }), piAgents, options.dryRun);
  }
  manifest.targets.piAgents = piAgents.files;
  counts.piAgents = piAgents.written;

  const previousManifest = readJson(MANIFEST_PATH, { targets: {} });
  const pruned = options.prune ? pruneStaleFiles(previousManifest, manifest, options.dryRun) : [];
  if (!options.dryRun) writeFileAtomic(MANIFEST_PATH, JSON.stringify(manifest, null, 2) + "\n", 0o644, false);

  return { counts, pruned, manifest };
}

/** Prints command usage. */
function printHelp() {
  console.log(`Usage: agents-publish [--check] [--dry-run] [--no-prune]\n\nPublishes ~/.agents canonical skills, agents, scripts, and prompt assets to Claude and Pi target directories.\n\nOptions:\n  --check     Validate canonical sources without writing files\n  --dry-run   Show what would be published without writing files\n  --no-prune  Do not remove files owned by an older publish manifest\n  --help      Show this help`);
}

/** Main CLI entrypoint. */
function main() {
  const args = new Set(process.argv.slice(2));
  if (args.has("--help") || args.has("-h")) {
    printHelp();
    return;
  }

  const errors = validateSources();
  if (errors.length > 0) {
    console.error("Source validation failed:");
    for (const error of errors) console.error(`- ${error}`);
    process.exitCode = 1;
    return;
  }

  if (args.has("--check")) {
    console.log("Source validation passed.");
    return;
  }

  const dryRun = args.has("--dry-run");
  const prune = !args.has("--no-prune");

  acquireLock();
  try {
    const result = publishAll({ dryRun, prune });
    const prefix = dryRun ? "Would publish" : "Published";
    console.log(`${prefix}:`);
    console.log(`- Claude skills: ${result.counts.claudeSkills}`);
    console.log(`- Claude agents: ${result.counts.claudeAgents}`);
    console.log(`- Claude agent prompts: ${result.counts.claudeAgentPrompts}`);
    console.log(`- Claude scripts: ${result.counts.claudeScripts}`);
    console.log(`- Pi agents: ${result.counts.piAgents}`);
    if (result.pruned.length > 0) console.log(`- Pruned stale files: ${result.pruned.length}`);
    if (!dryRun) console.log(`Manifest: ${displayPath(MANIFEST_PATH)}`);
  } finally {
    releaseLock();
  }
}

try {
  main();
} catch (error) {
  console.error(`agents-publish failed: ${formatError(error)}`);
  process.exitCode = 1;
}
