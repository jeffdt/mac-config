---
description: Create a draft pull request for the current branch
---

Follow these steps to create a draft pull request:

## Step 1: Check repository and branch status

- Run `git branch --show-current` to get the current branch name
- Verify we're not on `main` or `master` - if so, stop and inform the user
- Run `git status` to ensure the branch is pushed to remote
- If not pushed, push it first with `git push -u origin <branch-name>`

## Step 2: Check for PR template

- Look for `.github/pull_request_template.md` in the repository
- If it exists, read it to understand the expected structure and sections
- Use the template structure as a guide for the PR description

## Step 3: Analyze the changes

- Run `git log main...HEAD` or `git log master...HEAD` to see all commits in this branch
- Run `git diff main...HEAD` or `git diff master...HEAD` to see the full diff
- Understand what problem or feature is being addressed

## Step 4: Write the PR description

- Write a concise summary that explains the problem/feature and how this change resolves it
- **Be natural and conversational, not robotic or formulaic**
- Only explain what's not obvious from reading the code
- If there were non-obvious decisions or trade-offs, weave them naturally into the description
- Do NOT create separate sections with headers unless the template requires it
- Keep it brief and focused - avoid exhaustive explanations
- Follow the template structure if one exists

## Step 5: Create the PR

Use `gh pr create --draft` to create a draft PR. Set the base branch to `main` or `master` (whichever exists) and use the generated title and description.

After the PR is created:
- Run `gh pr view --json url -q .url | pbcopy`
- Inform the user the PR link has been copied to their clipboard

## Guidelines

- PR descriptions should be concise, not exhaustive
- Write naturally, avoid overly structured or robotic language
- Only explain non-obvious decisions - let the code speak for itself
- Follow repository's PR template structure if it exists
