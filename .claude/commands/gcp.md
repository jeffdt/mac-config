---
description: Git commit and push changes for current feature
---

First, execute the /gc command to commit changes.

After the commit is complete, push to remote:
- Push with `git push -u origin <branch-name>` (if first push)
- Or `git push` if branch already tracks remote

## Step 3: Check for existing PR

After pushing, check if there's an open PR for this branch:
- Run `gh pr view --json number,title,body,state` to check for an existing PR
- If no PR exists, we're done

## Step 4: Evaluate if PR description needs updating

If a PR exists, compare the changes just pushed against the current PR description:

1. Run `git diff HEAD~1..HEAD` to see what was just committed
2. Read the current PR description from the previous step
3. Evaluate whether the PR description is still accurate

**Update the PR description if:**
- The changes represent a fundamental shift in approach
- The description references code or decisions that are no longer accurate
- New significant functionality was added that the description doesn't mention

**Do NOT update for:**
- Bug fixes or minor corrections
- Code cleanup or refactoring
- Adding tests for already-described functionality
- Small tweaks that don't change the overall narrative

## Step 5: Update PR description (if needed)

If the description needs updating:
1. Draft an updated description that remains accurate
2. Keep it concise - don't add verbose explanations
3. Use `gh pr edit <number> --body "..."` to update
4. Inform the user what was changed and why

If no update is needed, briefly confirm the PR description is still accurate.
