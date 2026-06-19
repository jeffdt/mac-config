---
description: Commit, push, and create a draft PR
allowed-tools: SlashCommand:/ticket:find:*, SlashCommand:/gcp:*, SlashCommand:/pr:draft:*
---

Pre-computed context:
- Skip ticket linking: `!test -f .claude/local/skip-ticket && echo "YES" || echo "NO"`

## Step 1: Find the ticket

**If skip ticket linking is "YES":** Skip this step entirely. No ticket will be linked.

**Otherwise:** Use the SlashCommand tool to invoke /ticket:find with no arguments. This will auto-detect the relevant ticket from the branch name, commits, and conversation context.

Wait for the user to confirm or select a ticket. Store the result for use in Step 3.

## Step 2: Commit and push

Use the SlashCommand tool to invoke /gcp.

## Step 3: Create draft PR

Use the SlashCommand tool to invoke /pr:draft, passing the ticket identifier from Step 1 as the argument (or no argument if Step 1 was skipped). Do not ask for the ticket again.
