---
name: cross-repo-patterns
description: This skill should be used when brainstorming or writing plans for work that spans multiple repositories — especially when planning involves "app" and "k-repo", "client dependencies", "cross-repo contracts", "multi-repo parallelism", or when determining how repos should coordinate during parallel development. Surfaces known dependency patterns between repo pairs that affect parallel development strategy.
---

# Cross-Repo Dependency Patterns

When planning multi-repo work, certain repo pairs have known dependency relationships that affect how parallel development should be structured. Apply these patterns during brainstorming and plan-writing to ensure per-repo plans account for real-world constraints.

## How to Use

During brainstorming or writing-plans, check the repos involved against the patterns below. If a pattern matches:

1. Surface the constraint and recommended approach in the spec/plan
2. Encode the approach directly in each affected per-repo plan so agents can execute without additional coordination
3. Note any follow-up steps that happen after initial implementation (e.g., dependency bumps, client swaps)

## Patterns

### k-repo → app: Published Client Dependency

**Constraint:** k-repo publishes typed client libraries that app consumes as a dependency. App cannot import or test against the client until k-repo merges, the client is published, and app bumps its dependency version.

**Impact on parallelism:** Without mitigation, app would be blocked until k-repo completes. This defeats the purpose of parallel execution.

**Recommended approach — adapter boundary pattern:**

1. The **k-repo plan** implements and publishes the client as normal. No special handling needed.
2. The **app plan** implements against the contract using direct HTTP calls, structured behind a clean boundary (service class, adapter, thin wrapper — whatever is idiomatic). The boundary's interface should mirror the expected client interface.
   - All business logic calls through this boundary, never making raw HTTP calls directly
   - Tests mock at the boundary, validating behavior against the contract
   - This is production-quality code, not a temporary workaround — the contract is an HTTP API, and direct HTTP calls are a valid implementation
3. **Follow-up PR** (after k-repo merges and publishes): bump the client dependency in app, then swap the adapter internals from HTTP calls to client method calls. Business logic and tests remain unchanged.

**What to encode in per-repo plans:**

- **k-repo plan:** Standard implementation. Note that app will consume the client after it's published.
- **app plan:** Explicitly instruct the agent to implement behind an adapter boundary matching the expected client interface. Specify that direct HTTP calls are the initial implementation, and note the follow-up PR for the client swap. Include the contract (URL, method, request/response schema) inline so the agent can implement without the client existing.

**What NOT to do:**
- Do not block the app agent on k-repo completion
- Do not have the app agent write code that imports a non-existent client (Python's eager imports will prevent tests from running)
- Do not treat the HTTP implementation as throwaway — it's correct code against the contract
