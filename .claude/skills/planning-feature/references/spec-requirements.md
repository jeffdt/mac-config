# Design Spec Requirements

Full detail for what the design spec produced in Step 2 (Brainstorm) must contain, and what it must not.

## Multi-repo context to inject during brainstorming

- Organize by repo boundary. Flag cross-repo dependencies explicitly. Identify which repo owns each contract.
- The design spec MUST include a **Target Working Directory** per repo. Use the deepest directory whose subtree contains all planned changes for that repo, capped at service/component granularity:
  - Monorepos (k-repo): the service directory (e.g. `~/r/k-repo/python/klaviyo/executive_business_report/insights_service`), never deeper into individual subpackages/modules
  - Component-style repos (fender, app): the component or feature area
  - When uncertain or work spans the repo broadly: the repo root

  **Why this matters:** Claude Code loads `CLAUDE.md` files and path-scoped skills at session init by traversing up from cwd. Init-time context survives compaction; runtime discovery does not. Launching at the service/component level loads the deepest applicable `CLAUDE.md` plus all ancestors automatically.

  Each repo's section in the design spec should include a `**Target cwd:** <absolute path>` line that the agent records during brainstorming.
- The design spec MUST include a **Contracts** section defining all cross-repo boundaries:
  - API request/response schemas (JSON shapes, HTTP methods, status codes)
  - Event payload schemas
  - Shared type definitions
  - Error contracts (error codes, error response format)
  - Authentication/authorization expectations at boundaries
- The design spec MUST include a **Testing Strategy** section per repo describing:
  - A compact verification contract that maps every changed behavior or cross-repo boundary to its minimum required evidence: the testing layer (unit, component/integration, contract, end-to-end, or manual), the owner, and the reason that evidence is sufficient
  - Existing tests or coverage that remain sufficient, so implementation adds only the smallest missing proof rather than re-testing an already-covered path at another layer
  - How to locally verify the changes work (e.g., run existing test suites, curl an endpoint, trigger an event)
  - Which cross-repo boundaries need stub/mock services for local testing vs can be tested end-to-end. End-to-end testing is an exception: specify the unique integration risk it proves that lower-level or contract coverage cannot, and keep it to that risk
  - Any test data setup or environment prerequisites
  - This section describes the verification APPROACH and minimum proof, not specific test cases, assertions, or test-file structure
- The design spec MUST include an **Observability** section describing what production visibility the feature needs:
  - New metrics, logs, or traces required (name, dimensions/fields, what question they answer)
  - Existing instrumentation the feature relies on (and whether it's sufficient)
  - Cross-repo observability contracts (shared trace IDs, correlation fields, consistent log keys across boundaries)
  - What on-call needs to see when this fails (alerts, dashboards, log queries)
  - If genuinely none is needed, a one-line "no new instrumentation; existing X is sufficient" is acceptable and preferred over a fabricated list. The point is forcing the question, not bloating the spec.

## What NOT to include in the design spec

- Exact file paths or function signatures (the repo agent will determine these)
- Step-by-step implementation instructions
- Specific test cases, assertion logic, or test file structure (the repo agent determines these; the spec's Testing Strategy covers the approach)
- Utility or helper choices (the repo agent knows its local toolbox)
- Specific logger calls, metric client invocations, or log/trace field plumbing (the repo agent knows its local instrumentation libraries; the spec's Observability section covers WHAT to instrument and the cross-repo contract, not HOW)

The spec should describe WHAT each repo needs to do and the contracts it must satisfy, not HOW to implement it.
