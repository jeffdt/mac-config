#!/usr/bin/env bash
# PreToolUse guard: force a permission prompt before anything that publishes
# outward-facing GitHub content or notifies teammates.
#
# Returns permissionDecision "ask" (not "deny") so these actions stay possible —
# they just can't happen silently under defaultMode "auto"/bypassPermissions.
#
# Guarded:
#   - pull_request_review_write   method=submit_pending, or method=create with
#                                 an `event` (APPROVE/REQUEST_CHANGES/COMMENT)
#   - update_pull_request         draft=false (flips to ready), or reviewers=[...]
#   - create_pull_request         draft not true (INVERTED: fires on absence),
#                                 or reviewers=[...]
#   - gh pr review                publishes a review
#   - gh pr comment               publishes a comment
#   - gh pr ready                 takes a PR out of draft, notifies reviewers
#   - gh pr edit --add-reviewer   requests a review, notifies the reviewer
#   - gh pr create without        INVERTED: fires when --draft/-d is ABSENT
#     --draft/-d
#
# NOT guarded (the intended default path): creating a pending review, and
# add_comment_to_pending_review. A pending review is a legitimate terminal
# state — it persists on GitHub, only the author sees it, and it can be
# finished from the GitHub UI.

set -uo pipefail

# Machine-local opt-out. This script and its settings.json registration are both
# synced via the ~/.claude dotfiles repo, so the guard is on by default on every
# machine. To silence it on a personal machine:
#
#     touch ~/.claude/.gh-guard-off
#
# The marker is untracked automatically — ~/.claude/.gitignore ignores everything
# not explicitly allowlisted. Fail-safe by design: a forgotten marker means an
# extra prompt, never a silent publish.
[[ -f "$HOME/.claude/.gh-guard-off" ]] && exit 0

input=$(cat)

ask() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

tool=$(jq -r '.tool_name // ""' <<<"$input" 2>/dev/null) || exit 0

case "$tool" in
  *pull_request_review_write)
    method=$(jq -r '.tool_input.method // ""' <<<"$input")
    event=$(jq -r '.tool_input.event // ""' <<<"$input")
    if [[ "$method" == "submit_pending" || -n "$event" ]]; then
      ask "This PUBLISHES a PR review (method=${method:-none}, event=${event:-none}) and notifies the author and subscribers. Jeff publishes reviews himself — leave the review pending unless he explicitly approved submitting it."
    fi
    ;;

  *update_pull_request)
    # NB: `.draft // empty` is wrong here — jq's `//` treats boolean false as a
    # null-ish value, so draft=false (the case we care about) would collapse to
    # empty. Test for key presence instead.
    draft=$(jq -r '.tool_input | if has("draft") then (.draft | tostring) else "unset" end' <<<"$input")
    reviewers=$(jq -r '(.tool_input.reviewers // []) | length' <<<"$input")
    if [[ "$draft" == "false" ]]; then
      ask "This takes the PR OUT OF DRAFT, which notifies reviewers. Jeff keeps PRs in draft until he decides they're ready."
    fi
    if [[ "$reviewers" -gt 0 ]]; then
      ask "This REQUESTS REVIEWS from $reviewers reviewer(s) and pings them. Confirm with Jeff before requesting."
    fi
    ;;

  *create_pull_request)
    # Inverted: this one fires on the ABSENCE of draft, not its presence.
    # Same has() treatment — `.draft // x` would collapse an explicit false.
    draft=$(jq -r '.tool_input | if has("draft") then (.draft | tostring) else "unset" end' <<<"$input")
    reviewers=$(jq -r '(.tool_input.reviewers // []) | length' <<<"$input")
    if [[ "$draft" != "true" ]]; then
      ask "This creates a NON-DRAFT PR (draft=${draft}), which notifies reviewers immediately. Jeff always opens PRs as drafts — pass draft=true unless he said otherwise."
    fi
    if [[ "$reviewers" -gt 0 ]]; then
      ask "This creates a PR that REQUESTS REVIEWS from $reviewers reviewer(s) and pings them. Confirm with Jeff before requesting."
    fi
    ;;

  Bash)
    cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
    # Command start = line start, or after ; & | && || ( — so compound and
    # piped invocations are caught, not just a bare command.
    boundary='(^|[;&|(]|&&|\|\||[[:space:]])'

    if grep -Eq "${boundary}gh[[:space:]]+pr[[:space:]]+(review|comment)([[:space:]]|$)" <<<"$cmd"; then
      ask "This publishes outward-facing PR content via gh and pings teammates. Confirm with Jeff before sending."
    fi
    if grep -Eq "${boundary}gh[[:space:]]+pr[[:space:]]+ready([[:space:]]|$)" <<<"$cmd"; then
      ask "This takes a PR OUT OF DRAFT, which notifies reviewers. Jeff keeps PRs in draft until he decides they're ready."
    fi
    if grep -Eq "${boundary}gh[[:space:]]+pr[[:space:]]+edit([[:space:]]|$)" <<<"$cmd" \
       && grep -Eq '[-][-]add-reviewer' <<<"$cmd"; then
      ask "This REQUESTS A REVIEW and pings the reviewer. Confirm with Jeff before requesting."
    fi
    # Inverted: fires when `gh pr create` is missing --draft / -d.
    if grep -Eq "${boundary}gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)" <<<"$cmd" \
       && ! grep -Eq "([[:space:]])([-][-]draft|[-]d)([[:space:]]|=|$)" <<<"$cmd"; then
      ask "This creates a NON-DRAFT PR (no --draft/-d), which notifies reviewers immediately. Jeff always opens PRs as drafts — add --draft unless he said otherwise."
    fi
    ;;
esac

exit 0
