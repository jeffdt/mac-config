---
name: buildkite-mcp
description: >
  Use when about to call any `mcp__buildkite__*` tool, when the Buildkite MCP
  returns errors, or when diagnosing CI failures that need Buildkite data
  ("check buildkite", "get build logs", "analyze build failures").
---

# Buildkite MCP (Klaviyo)

Always pass `org_slug: "klaviyo-ci"` — **not** `klaviyo`, which returns
`{"message":"No organization found"}`. `org_slug` is required on these tools and
is not auto-resolved from the OAuth token. Web URLs follow the same slug:
`https://buildkite.com/klaviyo-ci/<pipeline>/builds/<n>`.

If `mcp__buildkite__*` calls fail with auth/401, re-auth: run `/mcp` and connect `buildkite`.
