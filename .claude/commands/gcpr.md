---
description: Commit, push, and create a draft PR
allowed-tools: SlashCommand:/gcp:*, SlashCommand:/pr:draft:*
---

## Step 1: Collect ticket number

Before doing anything else, ask the user: "What ticket is this work for? (e.g., AMPSS-123, or 'none')"

Wait for the user's response. Store the ticket info for use in Step 3. Do NOT proceed until the user answers.

## Step 2: Commit and push

Use the SlashCommand tool to invoke /gcp.

## Step 3: Create draft PR

Use the SlashCommand tool to invoke /pr:draft, passing the ticket identifier from Step 1 as the argument. Do not ask for the ticket again.
