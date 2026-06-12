---
name: git-commit
version: 1.0.0
description: This skill should be used when a slash command needs to perform a git commit, or when autonomously deciding to "commit changes", "create a commit", "stage and commit", "make a commit", or "save my work". It must also be loaded before running any `git commit` command as part of a larger workflow, including completing implementation, executing plan steps, wrapping up tasks, or any multi-step operation that ends with a commit. Even when committing feels like a minor step in a bigger flow, this skill defines branch safety, staging, and message formatting rules that must be followed.
---

# Git Commit Workflow

Standardized workflow for creating git commits with proper branch safety, intelligent staging, and message formatting.

## Context Requirements

This workflow requires the following git context:
- Current branch name
- Git status output
- Unstaged changes (git diff)
- Staged changes (git diff --staged)
- Recent commit history

**If invoked by a slash command:** This context is typically pre-computed and already present. Reference the existing context rather than re-running commands.

**If invoked standalone:** Gather the required context first:
```bash
git branch --show-current
git status
git diff
git diff --staged
git log -5 --oneline
```

## Step 1: Check for Customization

Check if a Skill named `formatting-commits` exists. If found, incorporate its guidance into commit message formatting in Step 4.

## Step 2: Verify Feature Branch

### Branch naming convention

All branches use the format `jeffdt/<domain>-<brief-kebab-description>`:
- **`jeffdt/`** prefix is mandatory
- **Domain** is the feature area or component (e.g., `insights`, `support-chat`, `auth`)
- **Description** is a short kebab-case identifier for the feature or bug
- Drop filler words like `service`, `system`, `module` to keep names concise
- Ticket numbers go in PR descriptions, not branch names
- Examples: `jeffdt/insights-add-cache-ttl`, `jeffdt/support-chat-verify-webhook`

### Logic

**If on `main` or `master`:**
- Check for `.claude/local/commit-to-main` in the repo root
- If the marker file exists, commit directly to main
- If it does NOT exist, infer the best branch name from the staged/unstaged changes, create it immediately with `git checkout -b <name>` (do NOT ask for confirmation), and proceed to staging

**If on a feature branch:**
- Proceed to staging

## Step 3: Stage Changes

Review the diff and status context, then stage relevant files.

**Staging approach:**
- Use `git add <specific-files>` for targeted staging
- Use `git add .` when all changes relate to the current feature

**Secret file protection - DO NOT stage:**
- `.env`, `.env.*` files
- `credentials.json`, `secrets.json`
- `.pem`, `.key`, `id_rsa` files
- Config files containing passwords or API keys

If secret files appear in the status, warn the user and exclude them from staging.

**Unrelated changes:**
If changes appear unrelated to the current feature based on file paths or content, use AskUserQuestion to confirm before staging.

## Step 4: Craft Commit Message

Create a clear, concise message following these conventions:

**Format rules:**
- Single line, approximately 50 characters (soft limit)
- Capitalize the first word
- Imperative mood: "Add feature" not "Added feature"
- No period at the end
- No prefixes like "feat:", "fix:", "chore:", etc.
- Focus on WHAT changed and WHY

**Good examples:**
- `Add user authentication with session management`
- `Fix race condition in payment processing`
- `Remove deprecated API endpoints`
- `Update error handling for network timeouts`

**Poor examples:**
- `fix: fixed the bug` (prefix, past tense, vague)
- `Updated stuff.` (past tense, vague, period)
- `WIP` (not descriptive)

## Step 5: Execute Commit

Run the commit command:
```bash
git commit -m "<message>"
```

Verify success:
```bash
git status
```

Confirm the working directory is clean or shows only intentionally unstaged files.

## Guidelines

- Default to feature branches; only commit to `main`/`master` when `.claude/local/commit-to-main` exists
- Keep commit messages to one sentence
- When unsure about grouping changes, ask the user
- Prefer smaller, focused commits over large mixed commits
