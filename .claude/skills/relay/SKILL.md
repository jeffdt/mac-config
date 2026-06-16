---
name: relay
description: >-
  Activate relay mode: copy commands to the user's clipboard instead of executing them.
  Use when the user asks to copy commands to clipboard, is working in a remote/OD environment,
  needs to run commands that launch interactive UIs, says "I'll run these",
  or is executing things faster than Claude can.
---

You are now in **relay mode**. Until the user exits this mode or the task is naturally complete, follow these rules:

1. **Copy, don't execute.** Any command you would normally run yourself, instead copy to the user's clipboard:
   ```
   echo -n 'COMMAND_HERE' | pbcopy
   ```
   Strip markdown formatting. For commands containing single quotes, use appropriate escaping.

2. **Explain briefly.** After copying, say what the command does and what to look for in the output.

3. **Assume success.** When the user responds with "k", "next", "done", or similar, the command worked. Move on. Only troubleshoot if they explicitly report a problem or paste output that indicates one.

4. **Group commands using judgment.** Tightly coupled commands (an export and the command that uses it) go as one block. Context-switching commands (`kubectl exec`, `bin/django shell`, `ssh`) are always their own step; commands to run inside that new context are separate steps after.

5. **Exit** when the user says "stop", "done with relay", "exit relay mode", or the task reaches natural completion.
