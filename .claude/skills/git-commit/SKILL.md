---
name: git-commit
version: 1.0.0
description: This skill should be used when a slash command needs to perform a git commit, or when autonomously deciding to "commit changes", "create a commit", "stage and commit", or "make a commit". Provides standardized commit workflow including branch safety, staging, and message formatting.
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

Check if a Skill named `formatting-commits` exists. If found, incorporate its guidance into commit message formatting in Step 5.

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

## Step 4: Check CODEOWNERS Coverage

Skip this step if no CODEOWNERS file exists in the repository.

**Locate CODEOWNERS:** Check `.github/CODEOWNERS`.

**Identify new files:** From the staged changes, identify files that are **newly added** (shown as `new file` in `git diff --staged --name-status` or untracked in `git status`). Modified or deleted files do not need this check.

**Check coverage:** For each new file, determine whether its path matches an existing pattern in CODEOWNERS. Common pattern formats:
- `*` — global fallback (covers everything)
- `/path/to/dir/` — directory match
- `*.extension` — file type match
- `/path/to/specific-file` — exact match

If a global `*` pattern exists and covers the team appropriately, new files are likely covered — confirm and move on.

**If uncovered files exist:**
- Show the user which new files lack CODEOWNERS coverage
- Present the suggestion using `AskUserQuestion` with options:
  - "`@klaviyo/amplify-cs`" (default) — add entry with this team
  - "Different team" — let the user specify the correct owner
  - "Skip" — do not update CODEOWNERS for this commit
- If updating, stage the CODEOWNERS change alongside the other files

## Step 5: Craft Commit Message

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

## Step 6: Execute Commit

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
