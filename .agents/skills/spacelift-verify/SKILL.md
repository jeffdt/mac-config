---
name: spacelift-verify
description: This skill should be used when verifying a Spacelift stack or run, especially after a PR merges and you need to confirm a new or existing environments/ stack ran clean. Use the spacectl CLI as the primary path. Triggers include "verify the Spacelift stack", "did the Spacelift run finish", "confirm the no-op in Spacelift", "did my merge create the stack", "check Spacelift after merge", "spacectl", or any request to find a stack's state, latest run, plan delta, or planning logs. Use it whenever Spacelift stacks, runs, the root parser, or post-merge infra verification come up, even if the user doesn't name the CLI or GraphQL fields, because it points straight at the commands that work and skips the subcommand-discovery detours that otherwise double the call count.
---

# Verifying Spacelift Stacks and Runs (spacectl)

`spacectl` is the Spacelift CLI. This skill exists to collapse a post-merge verification into **three commands** so you don't waste calls rediscovering which subcommand holds runs and logs. The running example is a no-op check: a new `environments/` stack created by a merge whose first tracked plan should report no changes. The same path works for any tracked run.

## The golden path

1. **(If a PR is involved) get the merge commit** from GitHub, so you can tie the run to it:
   ```bash
   gh pr view <n> -R <org/repo> --json mergeCommit
   ```

2. **Resolve the immutable stack ID by fuzzy search** (do this even if you think you know the name, see the trap below):
   ```bash
   spacectl stack list --search "<module-leaf-or-domain>" -o json
   ```
   Returns matching stacks with their immutable `id` and display `name`. Pick by `projectRoot` (it matches the path under `infrastructure/environments/...`).

3. **Get the whole verdict in one GraphQL call** via `spacectl api` (the document is sent unchanged):
   ```bash
   spacectl api 'query { stack(id: "<immutable-id>") {
     id name state stateIsTerminal autodeploy projectRoot branch
     trackedCommit { hash message }
     lastApplyAt
     runs {
       id type state finished branch
       commit { hash }
       delta { addCount changeCount deleteCount importCount moveCount forgetCount resources okCount failedCount }
     }
   } }'
   ```

4. **For the planning summary line**, pull it directly (don't fetch logs through GraphQL):
   ```bash
   spacectl stack logs --id "<immutable-id>" --run "<run-id>" --phase PLANNING | grep -ai "no changes"
   ```
   Use `--run-latest` instead of an explicit run ID for the latest run. Output carries ANSI color, hence `grep -a`.

## What a clean no-op looks like

On the module stack and its latest tracked run:
- Stack `state: FINISHED`, `stateIsTerminal: true`.
- Latest run is `type: TRACKED`, `branch: master`, `state: FINISHED`, `finished: true`, and (if you know the merge commit) `commit.hash` / `trackedCommit.hash` match it.
- Delta is zero across every `*Count`.
- Planning log contains `No changes. Your infrastructure matches the configuration.`
- `lastApplyAt: null` with no `APPLYING` phase is **expected** for a no-op (nothing to apply), not a failure. `autodeploy` may still be `true`. For a real change, expect non-zero counts and an apply phase instead.

## Gotchas (each cost a call if you don't know them)

- **Stack ID ≠ display name.** `stack(id:)` wants the hyphenated immutable ID (`environment-production-amplify_success-ebr-s3-prod`); the slash display name (`environment/production/amplify_success/ebr/s3-prod`) returns `{"data":{"stack":null}}`. Always get the ID from step 2's search, never hand-build it.
- **`runs` takes no pagination arg.** `runs(first: 1)` errors; select bare `runs { ... }` and read the latest from the front.
- **Logs live in `spacectl stack logs`,** not a `runs`/`run logs` subcommand. Filter with `--phase PLANNING`.
- If a field ever errors, dump the schema with `spacectl api --schema` rather than guessing.

## Auth

Run `spacectl whoami` first. If it errors on auth, the login token has lapsed (the SSO token lasts ~10 hours, so roughly daily). Don't stop and report the failure — just re-authenticate and continue:

```bash
spacectl profile login
```

This opens a browser for SSO; it blocks until the user finishes the login/grant flow in the browser, then returns control. Wait for it to exit, then re-run whatever command tripped the auth error. Treat this as one automatic retry per verification, not a loop — if `profile login` itself fails or the retried command still errors on auth, stop and report it instead of retrying again. This churn is expected for interactive use, not a misconfiguration. `spacectl profile list` shows the current profile.

## Parser stack (fallback only)

A root parser stack discovers config changes and creates/updates the per-environment module stacks. Check it only when the module stack doesn't exist yet, you need to prove the merge commit was processed, you're debugging stack creation, or the search was ambiguous:
```bash
spacectl api 'query { stack(id: "root-parser-<team>") { id name state runs { id state finished } } }'
```
Its delta reflects *Spacelift resources* (the stacks), not your Terraform plan, so don't read it as your infra signal. Skip it when the module stack already proves the commit, terminal success, zero delta, and the no-changes log.

## When spacectl can't see the stack (permission-scoped spaces)

Symptom: `spacectl stack list --search "<name>"` returns nothing, **and** a direct `spacectl api 'query { stack(id: "<guessed-id>") { ... } }'` returns `{"data":{"stack":null}}`, for a stack you have strong evidence exists (the root parser created it, it's linked in the PR's own comments). Don't conclude "no stack" from this and don't spiral into guessing stack-name variants; both symptoms together usually mean the stack lives in a **Spacelift space your profile isn't authorized to read**, not that it's missing. Known case: `machine_roles` / IAM roots live in an SRE/IAM-owned space that an `amplify` team profile can't see at all, so search comes back empty and the direct ID lookup nulls out, even though the stack is running fine.

When you hit this, stop hunting for the stack via spacectl and use the PR-comments fallback below instead.

## Fallback: read the Spacelift bot's PR comments

This works regardless of your spacectl space access, and is often faster than the stack-ID hunt even when spacectl *can* see the stack:

```bash
gh pr view <n> -R <org/repo> --json comments
```

Filter for the `spacelift-klaviyo` bot's comments. Each tracked stack gets its own comment with the same verdict you'd otherwise pull over GraphQL: `State: FINISHED`, a `Plan: N to add, 0 to change, 0 to destroy` line, a resource-change table, and "✅ Applied Successfully" (or the failure equivalent) when the run completes. Since this is posted by the bot itself, it's authoritative independent of what your profile can query.

**Worked example** (PR #251114, machine_roles/amplify-success/iam_machine_roles): spacectl was blind on this one; `stack list --search` came back empty and `stack(id:)` nulled out for every ID variant tried, because the stack lives in an SRE/IAM-owned space outside the `amplify` profile's access. The PR's `spacelift-klaviyo` comments settled it directly: prod showed `9 to add, 0 to change, 0 to destroy` and prod-eu showed `11 to add, 0 to change, 0 to destroy`, both "✅ Applied Successfully". No spacectl access needed.

*(Optional, background only: if the actual question is "why can't I see this / how do I get access" rather than "did it apply," that's a space-ownership question, not a run-verification one; see `~/r/spacelift-infrastructure` and its `amplify-spacelift-access-findings.md`. Not a required lookup for verification itself.)*

## Reporting

Give a verdict, not a dump: the merge/tracked commit, the module stack ID and `projectRoot`, the latest tracked run ID and state, the zero delta, the exact no-changes log line, and a note that `lastApplyAt: null` is expected for a no-op. Mention the parser only if you used the fallback.

**Worked example** (real verification, PR #238476, EBR S3):

> Verified against merge commit `42ec68e`. `spacectl stack list --search ebr` resolved `environment-production-amplify_success-ebr-s3-prod` (`projectRoot: infrastructure/environments/production/amplify-success/ebr/s3`). Latest tracked run `01KVZESCRFHBSVY12QN0YDZF35`, `FINISHED`, commit matches the merge. Delta all zero; planning log: "No changes. Your infrastructure matches the configuration." `lastApplyAt` null (no-op) — expected. Three commands, parser not needed.

## Alternate transport

The same GraphQL works through the Spacelift MCP, but it's OAuth-gated with ~10-hour tokens and exposes no tools once they lapse (a `401` easily mistaken for a missing capability). Prefer `spacectl`.
