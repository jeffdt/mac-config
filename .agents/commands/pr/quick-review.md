---
description: "Fast approve / don't approve pass on a PR: security and happy-path correctness only"
allowed-tools: Bash, Read, Grep, Glob, mcp__plugin_github_github__pull_request_read
model: sonnet
---

Quick-pass review of a GitHub PR (argument: PR number or URL; if none, resolve the PR for the current branch). This is a deliberately shallow gate for POCs and early-feedback work. Do not launch subagents and do not post anything to GitHub.

## Question to answer

Is this safe to ship to prod, and will the happy path do what the PR says it does?

## Procedure

1. Read the PR title, description, and the **entire** diff (`gh pr view`, `gh pr diff`). Never truncate it with `head`; for a large diff, page through it file by file (`gh pr diff --name-only`, then `git diff origin/main...HEAD -- <path>`). Skipping generated files, lockfiles, and test files is fine; skipping production code is not. For files the PR only deletes, don't read the deleted lines; search the rest of the repo for remaining references instead.
2. Read the code outside the diff wherever a verdict claim depends on it: callers, the settings loader, the authz helper, the query a new endpoint hits. Shallow means a narrow scope (the three checks below), not shallow reading. Treat the PR description as claims to verify, never as evidence, especially for security scoping.
3. If a command fails (zsh glob error, wrong path, missing file), fix it and retry. A failed grep is never a reason to stop checking.
4. Check only these:
   - **Security**: injection, authn/authz gaps, tenant or account isolation, secrets in code or logs, unsafe deserialization, SSRF, new public endpoints without access control, PII exposure.
   - **Correctness**: the main flow described by the PR works end to end; data is not corrupted or lost; migrations are safe to run on prod-size tables; no crash on the common path.
   - **Blast radius**: anything that could take down or degrade existing behavior for users who never touch the new feature.
5. Do NOT flag: style, naming, missing tests, error-path polish, edge cases off the happy path, performance tuning, refactoring suggestions, or anything that is merely "could be better". If it would not stop you from shipping a POC, leave it out.

## Output

Start with exactly one verdict line:

`APPROVE` or `DON'T APPROVE`

- **APPROVE**: one or two sentences on what you checked. Optionally up to three non-blocking notes, one line each.
- **DON'T APPROVE**: list each blocker as `file:line: what is wrong and why it matters in prod`, most severe first. Blockers only, no padding.

## Unverified claims

A claim that decides the verdict (security, happy path, blast radius) must be checked before you give it. "I couldn't confirm X" is not allowed when X can be reached by reading code, running a short local script, or querying GitHub.

Cross-repo dependencies are among the most valuable things to check. When the change needs an env var, secret, appfile entry, IAM grant, or other infra (usually in infrastructure-deployment), or the description says a companion PR handles it, confirm that:
- Linked or companion PRs: `gh pr view <n> --repo klaviyo/<repo>` for state, `gh pr diff <n> --repo klaviyo/<repo>` for contents. Check that the names and values match what this PR's code reads, for example the exact env var name under the right prefix and nesting delimiter.
- Already-merged config: read it from the local checkout under `~/r/<repo>` without touching its working tree (`git -C ~/r/<repo> fetch -q origin main`, then `git -C ~/r/<repo> show origin/main:<path>` or `git -C ~/r/<repo> grep <pattern> origin/main`).
- If the companion change is missing, unmerged when it must land first, or doesn't match the code, that is a blocker.

Only list something as unverified when it truly can't be reached from here, such as runtime behavior in a deployed environment or a third-party service's live config. If that item decides the verdict, the verdict is `DON'T APPROVE`, with the item listed as the blocker. Don't approve with a caveat.

Non-blocking notes don't need deep verification, but don't pad with guesses either: if a note would need real digging to stand up, drop it.

Don't write boilerplate such as "I did not run the tests". Running tests is not expected.
