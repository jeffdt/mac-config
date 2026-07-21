---
name: chub
description: >
  This skill should be used when writing code against a third-party library, SDK, or API
  and current documentation is needed — for example, "use the OpenAI API", "call the Stripe API",
  "use the Anthropic SDK", "query Pinecone", "integrate with Datadog", "use the Clerk auth SDK",
  or any time the task involves an external service and training knowledge may be outdated.
  Fetch docs with chub before writing code, rather than relying on training knowledge.
---

# Fetch API Docs with chub

When a task requires writing code against a third-party library or API, fetch current
documentation with the `chub` CLI instead of relying on training data. This ensures
correct, up-to-date API usage.

## Keeping Docs Fresh

Run `chub cache status` and check the "Last updated" timestamp. If the registry is
more than a day old, run `chub update` before searching.

## Core Workflow

### 1. Search for the doc

```bash
chub search "<library or service name>" --json
```

Pick the best-matching `id` from the results (e.g. `openai/chat`, `anthropic/claude-api`,
`stripe/api`). If nothing matches, try a broader term. Run `chub search` with no query
to list everything available.

IDs follow the `<author>/<name>` pattern — confirm the ID from search before fetching.

### 2. Fetch the docs

```bash
chub get <id> --lang py    # or --lang js, --lang ts
```

Omit `--lang` if the doc has only one language variant — it will be auto-selected.
If multiple languages exist and `--lang` is not passed, chub will list what's available.

For large docs with multiple reference files, use `--file` to grab specific sections
or `--full` for everything.

### 3. Write code from the docs

Read the fetched content and use it to write accurate code. Do not rely on memorized
API shapes — use what the docs say.

## Annotations

After completing a task, if a gotcha, workaround, version quirk, or project-specific
detail was discovered that isn't in the doc, save it for future sessions:

```bash
chub annotate <id> "Webhook verification requires raw body — do not parse before verifying"
```

Annotations are local, persist across sessions, and appear automatically on future
`chub get` calls. Keep notes concise and actionable. Do not repeat what's already in the doc.

To list all saved annotations: `chub annotate --list`

## Feedback

Rate docs so authors can improve them. Always confirm with the user before submitting.

```bash
chub feedback <id> up                        # doc worked well
chub feedback <id> down --label outdated     # doc needs updating
```

Labels: `outdated`, `inaccurate`, `incomplete`, `wrong-examples`, `wrong-version`,
`poorly-structured`, `accurate`, `well-structured`, `helpful`, `good-examples`.

## Quick Reference

| Goal | Command |
|------|---------|
| List everything | `chub search` |
| Find a doc | `chub search "stripe"` |
| Exact ID detail | `chub search stripe/api` |
| Fetch Python docs | `chub get stripe/api --lang py` |
| Fetch JS docs | `chub get openai/chat --lang js` |
| Fetch all files | `chub get anthropic/claude-api --full` |
| Fetch specific file | `chub get <id> --file ref.md` |
| Save to file | `chub get anthropic/claude-api --lang py -o docs.md` |
| Fetch multiple | `chub get openai/chat stripe/api --lang py` |
| Check registry age | `chub cache status` |
| Refresh registry | `chub update` |
| Save a note | `chub annotate stripe/api "needs raw body"` |
| List notes | `chub annotate --list` |
| Clear notes | `chub annotate stripe/api --clear` |
| Rate a doc | `chub feedback stripe/api up` |
