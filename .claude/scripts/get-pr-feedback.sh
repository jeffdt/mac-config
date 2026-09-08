#!/bin/bash
# Fetches unified PR feedback as compact JSON.
# Combines unresolved review threads, review submissions (with body),
# and general PR issue comments. Marks self-pending comments
# (comment.author == pr.author AND parent review state == PENDING).
#
# Usage: get-pr-feedback.sh <owner> <repo> <pr_number>
#
# Output: JSON object with this shape:
# {
#   "pr_author": "<login>",
#   "self_pending_reviews": [{ "review_id": "<id>", "comment_count": <n> }, ...],
#   "review_threads": [
#     {
#       "thread_id": "<id>",
#       "path": "...", "line": <n>, "start_line": <n|null>, "side": "RIGHT"|"LEFT",
#       "comments": [
#         {
#           "id": "<id>", "author": "<login>", "body": "...",
#           "created_at": "...", "review_id": "<id>",
#           "review_state": "PENDING"|"COMMENTED"|...,
#           "is_self_pending": true|false
#         }, ...
#       ]
#     }, ...
#   ],
#   "reviews": [
#     { "id": "...", "state": "...", "author": "...", "body": "...", "submitted_at": "..." }, ...
#   ],
#   "comments": [
#     { "id": "...", "author": "...", "body": "...", "created_at": "..." }, ...
#   ]
# }
#
# Filtering:
# - Resolved or outdated review threads are dropped entirely.
# - Review submissions with empty body are dropped (typical for plain approvals
#   or "changes requested" that only carry inline comments).
# - General PR comments are returned verbatim (no body filtering, since bot
#   summaries are often the most useful surface comment).

set -euo pipefail

OWNER="${1:-}"
REPO="${2:-}"
PR_NUMBER="${3:-}"

if [ -z "$OWNER" ] || [ -z "$REPO" ] || [ -z "$PR_NUMBER" ]; then
  echo "Usage: $0 <owner> <repo> <pr_number>" >&2
  exit 1
fi

THREADS=$(gh api graphql --paginate -f query='
query($owner: String!, $repo: String!, $pr: Int!, $cursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          startLine
          diffSide
          comments(first: 50) {
            nodes {
              id
              author { login }
              body
              createdAt
              pullRequestReview {
                id
                state
                author { login }
              }
            }
          }
        }
      }
    }
  }
}' -F owner="$OWNER" -F repo="$REPO" -F pr="$PR_NUMBER")

PR_META=$(gh api graphql -f query='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      author { login }
      reviews(first: 100) {
        nodes {
          id
          state
          author { login }
          body
          submittedAt
        }
      }
      comments(first: 100) {
        nodes {
          id
          author { login }
          body
          createdAt
        }
      }
    }
  }
}' -F owner="$OWNER" -F repo="$REPO" -F pr="$PR_NUMBER")

PR_AUTHOR=$(echo "$PR_META" | jq -r '.data.repository.pullRequest.author.login')

echo "$THREADS" | jq -s --arg author "$PR_AUTHOR" --argjson meta "$PR_META" '
  ([
    .[].data.repository.pullRequest.reviewThreads.nodes[]
    | select(.isResolved == false and .isOutdated == false)
    | {
        thread_id: .id,
        path: .path,
        line: .line,
        start_line: .startLine,
        side: .diffSide,
        comments: [.comments.nodes[] | {
          id: .id,
          author: .author.login,
          body: .body,
          created_at: .createdAt,
          review_id: .pullRequestReview.id,
          review_state: .pullRequestReview.state,
          is_self_pending: ((.author.login == $author) and (.pullRequestReview.state == "PENDING"))
        }]
      }
  ]) as $threads
  | {
      pr_author: $author,
      self_pending_reviews: (
        [$threads[].comments[] | select(.is_self_pending) | .review_id]
        | group_by(.)
        | map({ review_id: .[0], comment_count: length })
      ),
      review_threads: $threads,
      reviews: [
        $meta.data.repository.pullRequest.reviews.nodes[]
        | select(.body != null and .body != "")
        | {
            id: .id,
            state: .state,
            author: .author.login,
            body: .body,
            submitted_at: .submittedAt
          }
      ],
      comments: [
        $meta.data.repository.pullRequest.comments.nodes[]
        | {
            id: .id,
            author: .author.login,
            body: .body,
            created_at: .createdAt
          }
      ]
    }
'
