---
description: Git commit changes for current feature
---

Follow these steps to commit changes for the current feature:

## Step 1: Check current branch status

Run these commands in parallel:
- `git branch --show-current` to see the current branch
- `git status` to see what changes exist
- `git diff` to see unstaged changes
- `git diff --staged` to see already staged changes
- `git log -5 --oneline` to understand recent commit style in this repo

## Step 2: Ensure we're on a feature branch

**If currently on `main` or `master`:**
- Do not commit directly to the main branch
- Ask the user what branch name to use, or if there's a ticket/issue associated with this work
- Create the branch with `git checkout -b <branch-name>`

**If already on a feature branch:**
- Proceed with the commit

## Step 3: Stage changes

- Based on the changes reviewed, stage relevant files using `git add <files>` or `git add .`
- **DO NOT stage files that likely contain secrets**: .env, credentials.json, .pem, id_rsa, .key, config files with passwords, etc.
- If secret files are present, warn the user and exclude them from staging
- If there are changes that might not be related to the current feature, use AskUserQuestion to confirm before proceeding

## Step 4: Squash unpushed commits

- Check for unpushed commits using `git log @{upstream}..HEAD --oneline` (or against origin/main if no upstream)
- **If there are unpushed commits**, squash them with the new changes into one commit:
  - Use `git reset --soft @{upstream}` (or the base branch)
  - Stage all changes with `git add .`
- This keeps history clean with one commit per logical change

## Step 5: Craft and commit

Create a clear, concise commit message:
- Single line, ~50 characters (soft limit)
- Capitalize first word
- Imperative mood: "Add feature" not "Added feature"
- No period at the end
- No prefixes like "feat:", "fix:", etc.
- Focus on WHAT changed and WHY

**Examples:**
- "Add user authentication with session management"
- "Fix race condition in payment processing"
- "Remove deprecated API endpoints"

**Execute:**
- Commit with: `git commit -m "[message]"`
- Run `git status` to verify success

## Guidelines
- Never commit directly to `main` or `master`
- Keep commit messages to one sentence
- If unsure about grouping changes, ask the user
