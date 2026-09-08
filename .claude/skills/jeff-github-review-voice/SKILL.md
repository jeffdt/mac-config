---
name: jeff-github-review-voice
version: 2
description: "Use when the user asks to draft an inline GitHub PR review comment or feedback for a specific review finding. Write a short, natural teammate-to-teammate comment in Jeff's voice. Do not use for general writing, Slack messages, or PR descriptions."
---

> Generated from ~/.agents/skills/jeff-github-review-voice/SKILL.md. Do not edit this copy directly.
> Edit the source under ~/.agents, then run agents-publish.

# GitHub Review Voice

Draft the comment Jeff would actually type after noticing the issue. The goal is not an identifiable “voice”; it is a clear, specific note that sounds like a thoughtful teammate, not a review template.

## Core approach

- Keep the technical point intact. Do not replace it with generic approval language or a vague prompt.
- State the relevant failure mode when it makes the ask clearer. Omit background the author already knows.
- Make one concrete ask or observation per comment.
- Use the shortest shape that still says what matters. Most comments are one or two sentences.
- Read the result aloud once. If it sounds like a stock code-review phrase, rewrite it as something a person would say in a conversation.

## Avoid manufactured mannerisms

Do not use a phrase merely because it appears in an example. In particular, do not default to, repeat, or open a comment with:

- “Could …”
- “Probably want …”
- “Worth …?”
- “Thoughts on …?”
- “Any concerns …?”
- “Nit:”

Those are occasionally useful when they genuinely fit the point, but they are not a voice. Do not use `tbqh`, “maybe a dumb Q,” emojis, or self-deprecation unless the user specifically supplies that tone or context.

Do not follow artificial quotas for questions. Use a question only when you need information from the author. Otherwise, write a normal observation and a natural suggestion.

## Shape the comment around the finding

Use the finding's real language and name the code under discussion. Avoid explaining the entire diff back to its author.

For a test gap, say what the test currently fails to prove, then name the smallest useful test change. For example:

> This mocks `TracingInterceptor` itself, so the test would still pass if the `Client.connect()` call stopped accepting it. Can we assert on the real interceptor instance and its `always_create_workflow_spans` value instead?

For a behavior concern, state the condition and result, then ask for or suggest the resolution:

> If a conversation switch does not reset this map, entries will accumulate. We should rebase once history lands and test that path.

For a small code-quality suggestion, make the observation without treating it like a command:

> The leading underscore is misleading since these get imported. I think we should drop it.

For a true unknown, ask plainly:

> Is this duplicate line an accident?

## Severity and formatting

- Let the substance signal severity. Use `Nit:` only for a genuinely trivial point.
- Do not add “not a blocker” by default.
- Never issue commands such as “change this” or “please fix.”
- Use backticks for code, and use a GitHub suggestion block only for a small, directly applicable edit.
- No headers, greetings, praise padding, or review-summary language in an inline comment.

## Invocation

For a standalone request, turn the user's technical point into a comment. For “draft a comment for point N,” use the review finding as the technical source of truth.

Before returning it, check that it:

1. names the actual concern or desired change;
2. has no copied voice catchphrase;
3. would sound normal spoken aloud; and
4. has not lost important context in the name of brevity.

Copy the final comment to the clipboard with `pbcopy`, then display it in the conversation. On revision, update and re-copy it.

## Reference material

`references/voice-samples.md` contains historical comments for context, not templates to imitate. Prefer the rules above over copying its wording or quirks.
