---
name: create-pr
version: 1.0.0
description: This skill should be used when a slash command needs to create a pull request, or when autonomously deciding to "create a PR", "open a pull request", "create a draft PR", "submit for review", or "send this for review". It must also be loaded before running any `gh pr create` command as part of a larger workflow, including after completing implementation, executing plans, or wrapping up branch work. All PRs must be created as drafts with short, natural descriptions. Even when PR creation feels like the final step of a bigger task, this skill defines critical rules for draft mode, ticket linking, preflight checks, and description formatting that must be followed.
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

## Step 2: Preflight Checks

Run these checks in sequence before the quality pass. All checks are **fix-forward**: if something fails, diagnose and fix it, then re-run. Only surface the failure to the user (via AskUserQuestion) if you are genuinely stuck after a reasonable attempt.

If any check produces fixes, stage and commit them (using the `git-commit` skill) before moving to the next check.

### 2a. Test Suite

1. Detect the test command from repo context: Makefile targets, package.json scripts, CLAUDE.md instructions, repo-level skills, or conversation context. If no test command is identifiable, skip this check.
2. Run the test suite.
3. On failure: read the output, diagnose the root cause, fix the code, and re-run. Repeat until green.

### 2b. Build / Typecheck

1. Detect the build, compile, or typecheck command from the same sources as tests.
2. If no identifiable build step exists (e.g., a pure Python repo with no compilation), skip this check.
3. Run the build.
4. On failure: diagnose and fix, same loop as tests.

### 2c. CODEOWNERS

1. Check if `.github/CODEOWNERS` exists in the repo. If not, skip entirely.
2. Identify files added on the branch: `git diff --diff-filter=A --name-only main...HEAD` (fall back to `master`).
3. For each added file, check whether its path is covered by an existing CODEOWNERS pattern. If a global `*` pattern exists that maps to an appropriate team, all files are covered.
4. If uncovered files exist: add CODEOWNERS entries with `@klaviyo/amplify-cs` as the default team. Stage and commit.
5. Only ask the user (via AskUserQuestion) if the team assignment is genuinely ambiguous (e.g., files span multiple obvious team boundaries).

## Step 3: Simplify Pass

Before creating the PR, run a quality pass on all branch changes by invoking `/pr:simplify`. This reviews the full branch diff for reuse opportunities, code quality, and efficiency issues, and fixes anything it finds.

If `/pr:simplify` makes changes, stage and commit them (using the `git-commit` skill) before proceeding.

## Step 4: Verify Branch Status

- Verify not on `main` or `master` - if so, stop and inform the user
- If branch is not pushed to remote, push it first with `git push -u origin <branch-name>`

## Step 5: Analyze the Changes

- Run `git log main...HEAD` (or `master`) to see all commits on this branch
- Run `git diff main...HEAD` (or `master`) to see the full diff
- Understand what problem or feature is being addressed

## Step 6: Link the Ticket

**If `.claude/local/skip-ticket` exists in the repo root:** Skip this step entirely. Proceed without a ticket link.

Otherwise:

1. If the ticket is already known (passed as an argument or mentioned in conversation context), use it.
2. If not known, invoke `/ticket:find` with no arguments to auto-detect the ticket from branch name, commits, and conversation.
3. If auto-find returns a ticket, use it.
4. If auto-find returns "none" or no match, ask the user to provide a ticket identifier manually. Accept "none" if they confirm.
5. Place the ticket link at the **beginning** of the PR description using Linear's trigger phrase.
6. Format the ticket line as one of:
   - `Closes https://linear.app/klaviyo/issue/{TICKET-ID}` when this PR completes the ticket and no follow-up PRs are expected.
   - `Part of https://linear.app/klaviyo/issue/{TICKET-ID}` when this PR is one PR in a sequence for the ticket, or when follow-up PRs are expected.
7. Default to `Part of` if the PR is clearly a phase, migration step, scaffold, partial implementation, or otherwise does not finish the whole ticket.
8. If unsure whether the PR completes the ticket, ask the user whether to use `Closes` or `Part of`.
9. If the user confirmed "none", proceed without a ticket link.

## Step 7: Write the PR Description

Write a short, natural paragraph (2-4 sentences) explaining **why** the change exists and any non-obvious decisions. The diff shows *what* changed — the description should explain *why* and anything a reviewer wouldn't infer from the code alone.

**Tone:** Natural and conversational, not robotic or formulaic. No headers or bullet-point inventories unless the repo template requires them.

**Do NOT include any of the following — reviewers can see these from the diff and CI:**
- File counts, line counts, or change statistics
- Lists of files changed or modules touched
- Test counts, pass/fail status, or coverage metrics
- Bullet-point enumerations of every change made
- "What changed" / "Changes Made" / "Files Modified" inventories
- Section headers like "Testing", "Summary", "Changes" (unless repo template requires them)
- Self-evaluation ("clean", "robust", "comprehensive", etc.)

**Follow the repo's PR template structure if one exists.** When no template is present, the description is just the Linear trigger line from Step 6 (`Closes ...` or `Part of ...`) followed by the paragraph. If a template has a Linear, ticket, issue, or description field, put the trigger line there so Linear can auto-link it.

## Step 8: Create the PR

Use `gh pr create --draft` to create a draft PR:
- Set the base branch to `main` or `master` (whichever exists)
- Use the generated title and description

After the PR is created, inform the user with the PR URL.

## Guidelines

- **No conventional commit prefixes** in PR titles — no `feat:`, `fix:`, `chore:`, `refactor:`, etc. Just write a clear, imperative title (e.g., "Add cache TTL for insights queries" not "feat: Add cache TTL for insights queries")
- Let the diff speak for itself — the description adds context the diff can't provide
- Always create as draft — the user can mark ready when appropriate
- Always attempt to find a ticket via auto-find before asking manually. Accept "none" only as an explicit user override
- Follow the repository's PR template if it exists
