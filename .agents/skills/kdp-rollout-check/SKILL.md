---
name: kdp-rollout-check
version: 1.0.0
description: "Use when confirming a merged k-repo change is actually running on a KDP service's pods, especially a dev target: \"is it rolled out\", \"are the pods on the new image\", \"did the deploy finish\", \"is my change live on dev\", \"watch the rollout\", or after an Argo \"synced successfully\" notification. Jeff's own skill; it does not replace the team's deploy-timeline skill, which covers prod timing through Chronosphere."
---

# KDP rollout check

Merge, appfile bump, and Argo sync are requests. Only the pods prove a change is live. One script does the whole check:

```bash
~/.claude/scripts/kdp-rollout-state <appfile> <merge-sha> <kube-context> [pod-regex]
# e.g. a service on dev:
KREPO=<any k-repo checkout> ~/.claude/scripts/kdp-rollout-state \
  apps/<team>/<service>/app.yaml <merge-sha> <dev-context>
```

Without a regex, the script reads the appfile's enabled targets in `FLEET` (default `dev`) and requires each one, `<name>-<target>`, to have Running pods. That matches no sibling app that happens to share the name prefix, and it waits on a target that has no pods yet. Pass a regex only to narrow the check. Exit `0` means every matching Running pod is on the image that ships the merge, ready, and not terminating. `3` means not yet, with one line saying what it's waiting on. It plugs straight into the `watch-and-notify` skill:

```bash
~/.claude/scripts/watch -i 60 -t 5400 -- ~/.claude/scripts/kdp-rollout-state <args>
```

Run it in the background. Glass plays when the rollout is done; Basso plays at the timeout.

## Things that bit before

- **The image tag is a content hash, not a commit.** Don't compare it to the merge SHA. The bump commit's subject, `Updating appfile for <app> to <k-repo sha>`, is the only link back to the merge. The newest bump must contain the merge (`merge-base --is-ancestor`), and the target image comes from that bump's own diff (`git show <bump> -- <appfile> | grep '^+.*image:'`). Reading the image off the file at the wrong commit gives the wrong target.
- **Chronosphere doesn't cover dev.** It only has the prod clusters, so dev pods return empty results, which looks like "no pods". Use kubectl for dev.
- **Finding the dev context:** `klaviyocli k8s dev list-pods -n <ns> --all-contexts 2>/dev/null | grep <name>` adds every dev context to the kubeconfig and shows which one runs the service (Pika is on `dev-fern-use1-1`). The others return 403 or 401, which is normal. Filter by pod name: Pika's pods don't carry an `app=<name>` label.
- **Credentials:** `s2a-login` puts the session in env vars and `~/.aws/saml2aws_session`, not `~/.aws/credentials`, so a fresh shell gets `ExpiredToken`. The script sources the session file. If kubectl still fails, ask Jeff to run `s2a-login`; never start a login or role prompt without asking.
- **Argo's "synced" notification** names whichever infrastructure-deployment revision it synced to, often another app's bump. The sync counts only if that revision contains your bump.
- **Only Running pods count.** Failed and Succeeded pods left over from old ReplicaSets show up in the list and are noise.
- **Every deployment, not one.** A service can have several targets on the same image (Pika: `pika-dev` serves Slack and `pika-dev-turn-worker` runs turns), and a sibling app can share the name prefix (`pika-on-demand-dev`) while running a different image. The target-based default covers both cases.
- **Zsh:** quote `custom-columns=...[0]...`, or zsh tries to expand it as a glob.

## Timing

For Pika in Oct 2026 it took merge → bump about 13 minutes, then bump → pods ready about 18 minutes, so allow 30-plus minutes after merging before calling it stuck. A watch with a 90-minute timeout covers it.

A behavior check (for example, a new Slack footer showing up) proves at least one pod has the code, not that all do. Report it as live only once the script exits `0`.
