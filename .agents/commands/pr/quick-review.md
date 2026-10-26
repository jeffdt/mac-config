---
description: "Fast approve / don't approve pass on a PR: security and happy-path correctness only"
allowed-tools: Bash, Read, Grep, Glob, mcp__plugin_github_github__pull_request_read
model: sonnet
---

Quick-pass review of a GitHub PR (argument: PR number or URL; if none, resolve the PR for the current branch). This is a deliberately shallow gate for POCs and early-feedback work. Do not launch subagents and do not post anything to GitHub.

## Question to answer

Is this safe to ship to prod, and will the happy path do what the PR says it does?

## Procedure

1. Read the PR title, description, and diff (`gh pr view`, `gh pr diff`). Open surrounding code only when the diff alone cannot settle a suspicion.
2. Check only these:
   - **Security**: injection, authn/authz gaps, tenant or account isolation, secrets in code or logs, unsafe deserialization, SSRF, new public endpoints without access control, PII exposure.
   - **Correctness**: the main flow described by the PR works end to end; data is not corrupted or lost; migrations are safe to run on prod-size tables; no crash on the common path.
   - **Blast radius**: anything that could take down or degrade existing behavior for users who never touch the new feature.
3. Do NOT flag: style, naming, missing tests, error-path polish, edge cases off the happy path, performance tuning, refactoring suggestions, or anything that is merely "could be better". If it would not stop you from shipping a POC, leave it out.

## Output

Start with exactly one verdict line:

`APPROVE` or `DON'T APPROVE`

- **APPROVE**: one or two sentences on what you checked. Optionally up to three non-blocking notes, one line each.
- **DON'T APPROVE**: list each blocker as `file:line: what is wrong and why it matters in prod`, most severe first. Blockers only, no padding.

If you could not verify something that matters (for example, behavior that depends on code outside the diff you could not read), say so under the verdict rather than guessing.
