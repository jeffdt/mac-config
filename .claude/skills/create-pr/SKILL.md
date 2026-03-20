---
name: create-pr
version: 1.0.0
description: This skill should be used when a slash command needs to create a pull request, or when autonomously deciding to "create a PR", "open a pull request", "create a draft PR", or "submit for review". Provides standardized PR creation workflow including branch verification, change analysis, ticket linking, and natural description writing.
---

# Create PR Workflow

Standardized workflow for creating pull requests as drafts with natural, concise descriptions and proper ticket linking.

## Context Requirements

This workflow requires the following context:
- Current branch name
- Git status
- PR template (if one exists in the repo)

**If invoked by a slash command:** This context is typically pre-computed and already present. Reference the existing context rather than re-running commands.

**If invoked standalone:** Gather the required context first:
```bash
git branch --show-current
git status
cat .github/pull_request_template.md 2>/dev/null || echo "No PR template found"
```

## Step 1: Check for Customization

Check if a Skill named `formatting-prs` exists. If found, incorporate its guidance into the PR title and description.

## Step 2: Verify Branch Status

- Verify not on `main` or `master` - if so, stop and inform the user
- If branch is not pushed to remote, push it first with `git push -u origin <branch-name>`

## Step 3: Analyze the Changes

- Run `git log main...HEAD` (or `master`) to see all commits on this branch
- Run `git diff main...HEAD` (or `master`) to see the full diff
- Understand what problem or feature is being addressed

## Step 4: Link the Ticket

- If the ticket is already known from conversation context, use it
- If not known, ask the user before proceeding
- Place the ticket link at the **beginning** of the PR description
- Format: `https://linear.app/klaviyo/issue/{TICKET-ID}` (e.g., AMPSS-123)
- If no ticket exists, proceed without one

## Step 5: Write the PR Description

- Write a concise summary explaining the problem/feature and how this change resolves it
- **Be natural and conversational, not robotic or formulaic**
- Only explain what's not obvious from reading the code
- If there were non-obvious decisions or trade-offs, weave them naturally into the description
- Do NOT create separate sections with headers unless the repo template requires it
- Keep it brief and focused
- Follow the repo's PR template structure if one exists

## Step 6: Create the PR

Use `gh pr create --draft` to create a draft PR:
- Set the base branch to `main` or `master` (whichever exists)
- Use the generated title and description

After the PR is created, inform the user with the PR URL.

## Guidelines

- PR descriptions should be concise, not exhaustive
- Write naturally - avoid overly structured or robotic language
- Only explain non-obvious decisions - let the code speak for itself
- Follow the repository's PR template if it exists
- Always create as draft - the user can mark ready when appropriate
- Always include a ticket link unless explicitly told there is no ticket
