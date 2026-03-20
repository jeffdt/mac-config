---
name: git-push
version: 1.0.0
description: This skill should be used when a slash command needs to push code to remote, or when autonomously deciding to "push changes", "push to remote", "push code", or "update the remote branch". Provides standardized push workflow including remote tracking, existing PR detection, and intelligent PR description updates.
---

# Git Push Workflow

Standardized workflow for pushing commits to remote with intelligent PR description management.

## Context Requirements

This workflow requires the following context:
- Current branch name
- Whether the branch tracks a remote
- Existing PR information (if any)

**If invoked by a slash command:** This context is typically pre-computed and already present. Reference the existing context rather than re-running commands.

**If invoked standalone:** Gather the required context first:
```bash
git branch --show-current
git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null
gh pr view --json number,title,body,state 2>&1 || echo "No PR exists"
```

## Step 1: Squash Unpushed Commits

Maintain clean history by squashing multiple unpushed commits into one before pushing.

1. Save the most recent commit message: `git log -1 --format=%B`
2. Count unpushed commits: `git rev-list @{upstream}..HEAD --count 2>/dev/null`
   - If no upstream exists, count against `origin/main` or `origin/master`
3. If count > 1:
   - `git reset --soft @{upstream}` (or base branch if no upstream)
   - `git add .`
   - `git commit -m "<saved commit message>"`
4. If count <= 1: skip squashing, proceed to push

## Step 2: Push to Remote

- If branch has no upstream: `git push -u origin <branch-name>`
- If branch already tracks remote: `git push`

## Step 3: Check for Existing PR

Review whether a PR exists for this branch (from context or by running `gh pr view`).

If no PR exists, the workflow is complete.

## Step 4: Evaluate PR Description

If a PR exists, determine whether the description needs updating:

1. Review the current commit message and the PR description
2. Compare them thematically — does the description still accurately describe what the branch does?

**Update the PR description if:**
- Changes represent a fundamental shift in approach
- Description references code or decisions that are no longer accurate
- New significant functionality was added that the description doesn't mention

**Do NOT update for:**
- Bug fixes or minor corrections
- Code cleanup or refactoring
- Adding tests for already-described functionality
- Small tweaks that don't change the overall narrative

Default to NOT updating. Most pushes don't warrant a description change.

## Step 5: Update PR Description (if needed)

If an update is warranted, first check PR ownership:

1. Get the PR author from pre-computed context if available (e.g. the `author` field from `/gcp`), otherwise fall back to: `gh pr view --json author --jq '.author.login'`
2. **If the author is `jeffdt-k`:** proceed with the update directly.
3. **If the author is anyone else:** use AskUserQuestion to confirm before updating:
   - "Update {author}'s PR #{number} description? 1. Yes 2. No 3. (type a reply)"
   - If the user selects No or declines, skip the update and move on.

When proceeding with the update:
1. Check if a Skill named `formatting-prs` exists and apply its guidance
2. Draft an updated description that remains accurate
3. Keep it concise - avoid verbose explanations
4. Use `gh pr edit <number> --body "..."` to update
5. Inform the user what was changed and why

If no update is needed, briefly confirm the PR description is still accurate.

## Guidelines

- Always push with `-u` on first push to set upstream tracking
- Default to NOT updating PR descriptions - only update for meaningful changes
- When updating, preserve the existing description's tone and structure
- Never force-push unless explicitly asked by the user
