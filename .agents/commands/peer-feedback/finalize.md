---
description: Finalize peer feedback for submission
---

# Peer Feedback Finalize

## Pre-computed Context

- Review year: !`date +%Y`

**Note:** Use the review year from pre-computed context for all file paths below.

## Determine Subject

**If `$ARGUMENTS` is provided**: Use that as the person's name.

**If no arguments provided**, infer the subject:
1. Check conversation context for a name we've been discussing (e.g., from recent drafting)
2. If not in context, list folders in `Career/<YEAR>/Peer Feedback/` that have `Draft *.md` files (ready to finalize)
3. If exactly one person has drafts, confirm: "Finalize feedback for [Name]?"
4. If multiple or none found, ask the user who they want to finalize

Once the subject is determined, use their name wherever `$ARGUMENTS` appears below.

## Instructions

1. Find the highest numbered draft in `Career/<YEAR>/Peer Feedback/$ARGUMENTS/`
2. Read the draft and check for unaddressed feedback:
   - **Inline bold comments** (`**like this**`) within the draft text
   - **Draft Feedback section** at the end of the file
   - **If feedback exists** (either type): Use the **AskUserQuestion** tool with two options:
     1. "Implement feedback" - Create a new draft addressing the feedback first
     2. "Ignore and finalize" - Discard the feedback and proceed to finalize
   - **If no feedback**: Proceed to finalize
3. Create the final file at `Career/<YEAR>/Peer Feedback/$ARGUMENTS/Final.md`

## Final File Format

The final file should contain:
- A header with the person's name
- Each question followed by the answer in a fenced code block (triple backticks) so Obsidian provides a Copy button

Example structure:
```
# $ARGUMENTS - Peer Feedback <YEAR>

## Question 1
How did you see this Klaviyo create impact this year...

```
[Answer text here - ready to paste into the form]
```

## Question 2
Please share feedback that would help this Klaviyo...

```
[Answer text here - ready to paste into the form]
```
```

## Cleanup

After creating the final file:
1. Delete all `Draft *.md` files in the person's folder
2. Confirm to the user what was deleted
3. The folder should now contain only:
   - `References.md`
   - `Final.md`
