---
name: watch-and-notify
version: 1.4.0
description: "Use when the user wants to be told, with a sound, when something outside this session finishes: a PR merging or failing CI, a deploy or rollout, a build, a migration, a long job. Triggers include \"watch it\", \"tell me when it merges\", \"ping me when it lands\", \"let me know when the deploy finishes\", \"play a sound when it's done\", \"afplay when it happens\", \"monitor this\". Not for waiting on work this session started in the background; the harness already reports that."
---

# Watch and notify

`~/.claude/scripts/watch` runs a check command over and over, in the background, until the check says it's done. Then it prints the check's last output, loops a sound for 3 seconds (`Glass.aiff` on success, `Basso.aiff` on failure), and speaks two short sentences in two voices: "Message from <tmux session>, <window>." (when inside tmux), then the outcome, e.g. "Message from agents, text-to-speech. CI passed." The user juggles many sessions at once; the tmux window tells them which one fired. Use it instead of writing a polling loop by hand.

```bash
~/.claude/scripts/watch [-i poll-seconds] [-t timeout-seconds] -- <check command...>
```

The check's last output line is the outcome, so make it a short sentence saying what happened, not just "done": "CI passed", "Merged", "Spacelift apply finished", "Spacelift plan failed", "Rollout complete", "Rollout stalled". Detail for the terminal (failing check names, IDs) goes on earlier lines; only the last line is spoken. A timeout is spoken as "timed out after N minutes".

The check's exit code decides each poll: `0` done and succeeded, `1` done and failed, anything else (use `3`) still waiting. A `-t` timeout counts as a failure. `watch` exits with the final code. The default poll is 90 seconds. `WATCH_OK_SOUND`, `WATCH_BAD_SOUND` and `WATCH_SECONDS` change the sounds and how long they loop; `WATCH_HEADER_VOICE` sets the voice for the "Message from" part (default Daniel); `WATCH_SAY=0` turns speech off.

Always start it with the Bash tool's `run_in_background`, and tell the user which outcomes make which sound and what will be spoken.

## Built-in check: a pull request

```bash
~/.claude/scripts/watch -- ~/.claude/scripts/watch-pr-state [--until ci] <pr>   # run inside a checkout of the PR's repo
```

By default success is merged (spoken "Merged"). With `--until ci`, success is every CI check finished with none failing (spoken "CI passed"); use it when the user wants to know when to open a draft for review. Failure is closed without merging ("Closed without merging"), the Trunk merge queue's newest state `Failed` or `Cancelled` ("Failed the merge queue"), or any failing CI check on the head commit ("CI failed"). `Not Ready`, `Pending` and `Testing` keep waiting. Repos without Trunk use only GitHub's state and checks.

## Anything else: write a small check

When there's no built-in check, pass an inline one whose last output line is a spoken outcome and that exits `0`, `1` or `3`. Base it on a state the system reports, not on elapsed time. For example, a Kubernetes rollout:

```bash
~/.claude/scripts/watch -i 30 -t 1800 -- sh -c '
  kubectl rollout status deploy/pika -n pika --timeout=5s >/dev/null 2>&1 && { echo "Rollout complete"; exit 0; }
  kubectl get deploy/pika -n pika -o jsonpath="{.status.conditions[?(@.type==\"Progressing\")].reason}" | grep -q ProgressDeadlineExceeded && { echo "Rollout stalled"; exit 1; }
  echo "rolling out"; exit 3'
```

Give a long-running watch a `-t` so a check that never settles still ends with a sound. If the same kind of check comes up again, save it as a script next to `watch-pr-state` in `~/.agents/scripts/` instead of retyping it.

## Gotchas

- A background watch dies with the session. After a restart or compaction, check the state yourself and start a new watch if it's still pending.
- Status output that lists history (Trunk does) keeps old failures around. Read only the newest entry, or an earlier attempt's failure ends a watch on the retry.
- Don't treat "still waiting" as failure. A check that errors out (no network, CLI not logged in) should exit `3` and try again, unless the error means the thing itself failed.
