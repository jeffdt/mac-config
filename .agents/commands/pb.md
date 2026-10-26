---
description: Copy relevant command or text from recent output to clipboard
argument-hint: [hint]
allowed-tools: Bash(echo:*), Bash(afplay:*), Bash(osascript:*), AskUserQuestion
---

Analyze the recent conversation output and identify the most relevant command(s) or text snippet(s) that the user would likely want to copy to their clipboard.

**Hint**: $ARGUMENTS

## What to look for

1. **Shell commands** - Any bash/terminal commands that were shown or suggested
2. **Code snippets** - Small pieces of code that might be useful to copy
3. **URLs** - Links that were referenced
4. **File paths** - Important paths mentioned
5. **Error messages** - Key error text that might need to be shared/searched

## Decision process

**If a hint was provided** (`$ARGUMENTS` is not empty): Use the hint to match against candidates. The hint is a fuzzy keyword — match it against tool names, CLI names, partial command text, or any identifying word in the candidates. For example:
- `cli` or `klaviyocli` → match a `klaviyocli` command
- `op` or `1pass` → match an `op` (1Password CLI) command
- `git` → match a git command
- `url` → match a URL

If the hint clearly matches one candidate, copy it directly. If it matches multiple or none, fall back to the normal flow below but mention the hint didn't narrow it down.

**If no hint was provided**, use the standard flow:

1. **Single clear candidate**: If there's one obvious command or text to copy (e.g., a command that was just suggested to run), copy it directly using `pbcopy`

2. **Multiple candidates**: If there are 2-4 reasonable options, use the AskUserQuestion tool to let the user pick which one they want copied. Present them clearly with brief context.

3. **No candidates**: If there's nothing obvious to copy from recent output, inform the user and ask what they'd like to copy.

## Execution

Once the text is identified (either automatically or via user selection):

```bash
echo -n "THE_TEXT_HERE" | pbcopy
```

Use `echo -n` to avoid adding a trailing newline.

After copying, confirm what was copied to the clipboard with a brief message.

## Important

- Prefer commands/code over prose explanations
- For multi-line content, preserve the formatting
- Strip any markdown formatting (like backticks) from the actual copied content
- If a command has placeholder values, ask if the user wants the template or needs to fill in values first
