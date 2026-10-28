#!/usr/bin/env bash
# PostToolUse hook (matcher: Write): when an implementation plan lands in a
# plans/ directory, inject a size check so splits get decided before any code
# is written. Splitting after implementation means re-cutting branches and
# re-testing; at plan time it costs nothing. Silent for every other write, so
# sessions that never write a plan pay no context for it.

set -uo pipefail

input=$(cat)
file_path=$(jq -r '.tool_input.file_path // ""' <<<"$input" 2>/dev/null) || exit 0

[[ "$file_path" == */plans/*.md ]] || exit 0

read -r -d '' note <<'EOF'
Plan size check, do this before presenting the plan or starting implementation:
1. Estimate added lines per task, production and tests separately, and a total.
2. Each behavior gets tested at one layer. Flag any task that tests the same behavior again at another layer (store, service, handler), and drop the duplicate from the plan.
3. Replace "add a helper/method if nothing fits" escape hatches with a named existing helper, or state the new one explicitly.
4. If the total is past roughly 600 lines, or a reviewer would be surprised by the diff given the PR title, propose a split into separate PRs now and say where the seam is.
Add the estimate to the plan under a "Size" heading so the PR step can compare against it.
EOF

jq -n --arg ctx "$note" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'
