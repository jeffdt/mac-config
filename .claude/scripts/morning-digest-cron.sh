#!/bin/bash
set -euo pipefail

# morning-digest-cron.sh: Mon-Fri 9am unified morning digest. Generates the
# previous workday's /pkm:daily-log entry (with self-healing for 1-3 day
# gaps), prunes worktrees, distills the log via Haiku, and posts one Slack
# message combining all sections. Designed to be extended with additional
# sections (e.g., PRs awaiting review) by appending to the sections array
# in the compose phase. See ~/.claude/specs/2026-05-06-morning-digest-cron-design.md

# CLI flags
DRY_RUN=0
DATE_OVERRIDE=""
REPOST=0
MODE="all"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --date)    DATE_OVERRIDE="$2"; shift 2 ;;
    --repost)  REPOST=1; MODE="post"; DATE_OVERRIDE="$2"; shift 2 ;;
    --generate-only) MODE="generate"; shift ;;
    --post-only) MODE="post"; shift ;;
    -h|--help)
      echo "usage: morning-digest-cron.sh [--dry-run] [--date YYYY-MM-DD] [--generate-only] [--post-only] [--repost YYYY-MM-DD]"
      echo
      echo "  --generate-only  only create any missing daily log files; no Slack post"
      echo "  --post-only      compose and post from existing files; never generate logs"
      echo "  --repost         compatibility alias for --post-only --date YYYY-MM-DD"
      exit 0
      ;;
    *)
      echo "unknown flag: $1" >&2
      exit 2
      ;;
  esac
done

# Reap any spawned claude children on exit (normal or error). The `|| true`
# prevents pkill returning 1 (no matches) from leaking into the script's exit
# status when set -e is in effect.
trap 'pkill -P $$ >/dev/null 2>&1 || true' EXIT

# fnm-managed node lives outside the launchd PATH (/opt/homebrew/bin:...), so
# plugin hooks that shell out to `node` (SessionEnd lifecycle hook, etc.) spam
# "node: command not found" into daily-log.stderr.log. The aliases/default
# symlink is the stable path fnm keeps pointed at the current default version.
FNM_DEFAULT_BIN="$HOME/.local/share/fnm/aliases/default/bin"
[[ -x "$FNM_DEFAULT_BIN/node" ]] && PATH="$FNM_DEFAULT_BIN:$PATH"
export PATH

# Phase 1: target_date computation
if [[ -n "$DATE_OVERRIDE" ]]; then
  if ! date -j -f "%Y-%m-%d" "$DATE_OVERRIDE" "+%Y-%m-%d" >/dev/null 2>&1; then
    echo "invalid --date value: $DATE_OVERRIDE (expected YYYY-MM-DD)" >&2
    exit 2
  fi
  TARGET_DATE="$DATE_OVERRIDE"
else
  today_dow=$(date +%u)  # 1=Mon, 7=Sun
  case "$today_dow" in
    1) TARGET_DATE=$(date -v-3d +%Y-%m-%d) ;;  # Mon → Fri
    *) TARGET_DATE=$(date -v-1d +%Y-%m-%d) ;;  # Tue-Fri → yesterday
  esac
fi
TARGET_DAY_LONG=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" "+%A")
TARGET_DAY_SHORT=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" "+%a")
TARGET_FILENAME_DATE=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" "+%y-%m-%d")

# Phase 2: gap detection
DAILY_DIR="$HOME/o/Daily"
mkdir -p "$DAILY_DIR"

TARGET_FILE="$DAILY_DIR/$TARGET_FILENAME_DATE ($TARGET_DAY_SHORT).md"

if [[ "$REPOST" == "1" && ! -f "$TARGET_FILE" ]]; then
  echo "--repost requested but $TARGET_FILE does not exist" >&2
  exit 2
fi

# Guard with `|| true` because `head -n1` triggers SIGPIPE on the upstream
# `sort`, which pipefail converts to a non-zero pipeline exit and set -e
# would abort on. The empty-string fallback is handled by the branches below.
MOST_RECENT=$(ls -1 "$DAILY_DIR" 2>/dev/null \
  | grep -E '^[0-9]{2}-[0-9]{2}-[0-9]{2} \([A-Z][a-z]{2}\)\.md$' \
  | sort -r \
  | head -n1 \
  | sed -E 's/^([0-9]{2})-([0-9]{2})-([0-9]{2}) .*/20\1-\2-\3/' \
  || true)

GAP_DATES=()
if [[ -f "$TARGET_FILE" ]]; then
  : # target already present — gap=0
elif [[ -z "$MOST_RECENT" || "$MOST_RECENT" > "$TARGET_DATE" ]]; then
  # Daily/ is empty, OR the most recent existing entry is newer than target
  # (a "hole" — target's file was removed). Generate just the target.
  GAP_DATES=("$TARGET_DATE")
else
  cursor=$(date -j -v+1d -f "%Y-%m-%d" "$MOST_RECENT" "+%Y-%m-%d")
  while [[ "$cursor" < "$TARGET_DATE" || "$cursor" == "$TARGET_DATE" ]]; do
    cursor_dow=$(date -j -f "%Y-%m-%d" "$cursor" "+%u")
    if [[ "$cursor_dow" -lt 6 ]]; then
      GAP_DATES+=("$cursor")
    fi
    cursor=$(date -j -v+1d -f "%Y-%m-%d" "$cursor" "+%Y-%m-%d")
  done
fi

if [[ "$MODE" == "post" ]]; then
  GAP_DATES=()
fi
GAP_DAYS=${#GAP_DATES[@]}

WT="/opt/homebrew/bin/wt"
CLAUDE="${CLAUDE:-$HOME/.local/bin/claude}"

# Use ANTHROPIC_API_KEY for all `claude -p` calls if the Keychain entry exists.
# This sidesteps the OAuth refresh-storm pattern documented at
# ~/.claude/projects/-Users-jeff-diteodoro-Klaviyo-projects-morning-digest/memory/claude-cli-auth-lapse.md
# (see anthropics/claude-code#58066). Trade-off: these calls bill against the
# API key, not Jeff's Max subscription. Phase 4 (/pkm:daily-log, default Opus
# model) is the only non-trivial cost; the other three are Haiku. Key was
# loaded once from 1Password ("Anthropic API Key - jeff.diteodoro - Pi Agent
# Harness" in Employee vault) into the login keychain via:
#   security add-generic-password -U -A -s morning-digest-anthropic-api-key -a "$USER" -w "<key>"
if _ak=$(security find-generic-password -w \
              -s morning-digest-anthropic-api-key \
              -a "$USER" 2>/dev/null); then
  ANTHROPIC_API_KEY="$_ak"
  export ANTHROPIC_API_KEY
  unset _ak
  AUTH_MODE="api-key"
else
  AUTH_MODE="oauth"
fi

REPOS=(
  "$HOME/r/app"
  "$HOME/r/k-repo"
  "$HOME/r/fender"
  "$HOME/r/infrastructure-deployment"
)

LOG_DIR="$HOME/.local/share/wt-prune"
LOG_FILE="$LOG_DIR/history.log"
DIGEST_LOG_DIR="$HOME/.local/share/morning-digest"
mkdir -p "$DIGEST_LOG_DIR"
SLACK_CHANNEL="C0ARVJ72P2B"

# Log-line timestamp. Evaluated at write time (not captured once at startup), so
# late phases — the Phase 4 timeout line and MCP-health lines, written ~20min in
# — show when they actually happened instead of the script's start time.
now_ts() { date -u +"%Y-%m-%dT%H:%M:%S"; }

# Tunables
STALE_AGE_DAYS=14  # orphan (no-remote, clean) worktrees older than this auto-remove
AGING_AGE_DAYS=30  # worktrees older than this that don't qualify for removal get flagged in Slack

mkdir -p "$LOG_DIR"

notify_slack() {
  local message="$1"
  local latest_message="$DIGEST_LOG_DIR/latest-message.md"
  local pending_message="$DIGEST_LOG_DIR/pending-message-$(date -u +%Y%m%dT%H%M%SZ).md"

  printf "%s\n" "$message" > "$latest_message"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "=== DRY RUN: would post to Slack ==="
    echo "$message"
    echo "=== END DRY RUN ==="
    return 0
  fi
  if "$CLAUDE" -p "Send a Slack message to channel ID $SLACK_CHANNEL with this exact message (preserve markdown formatting): $message" \
    --model haiku \
    --allowedTools "mcp__plugin_slack_slack__slack_send_message" \
    --permission-mode bypassPermissions \
    </dev/null \
    >> "$LOG_DIR/claude-notify.log" 2>&1; then
    return 0
  else
    cp "$latest_message" "$pending_message"
    echo "$(now_ts) AUTO NOTIFY-FAILED saved $pending_message (see claude-notify.log)" >> "$LOG_FILE"
    return 1
  fi
}

url_encode_filename() {
  # Minimal URL-encoder for Obsidian deep links.
  # Handles space ( → %20) and parens ( → %28/%29) which are the only
  # special chars in our YY-MM-DD (Day) filename pattern.
  local s="$1"
  s="${s// /%20}"
  s="${s//(/%28}"
  s="${s//)/%29}"
  echo "$s"
}

wt_prune_section=""

if [[ "$MODE" != "generate" ]]; then
removed=()  # "repo|ref|reason"
aging=()    # "repo|ref|age|reason"

for repo in "${REPOS[@]}"; do
  if [[ ! -d "$repo/.git" ]]; then
    continue
  fi

  repo_name=$(basename "$repo")

  tsv=$(
    $WT list --format json -C "$repo" 2>/dev/null \
      | STALE_AGE=$STALE_AGE_DAYS AGING_AGE=$AGING_AGE_DAYS python3 -c "
import json, sys, os, time
now = int(time.time())
stale_age = int(os.environ['STALE_AGE'])
aging_age = int(os.environ['AGING_AGE'])
data = json.load(sys.stdin)
for item in data:
    if item.get('is_main'):
        continue
    branch = item.get('branch') or ''
    path = item.get('path') or ''
    # Exempt the legacy unnumbered .pr-review slot (see commit c96963b).
    # Per-PR slots (.pr-review-<digits>) are NOT exempt: they should reap
    # like normal worktrees once their PR is merged or they go stale.
    if os.path.basename(path).endswith('.pr-review'):
        continue
    # Mode: BRANCH (use wt remove) or PATH (use git worktree remove for detached)
    if branch:
        mode, ref, display = 'BRANCH', branch, branch
    elif path:
        mode, ref, display = 'PATH', path, f'(detached) {os.path.basename(path)}'
    else:
        continue
    state = item.get('main_state') or ''
    ts = item.get('commit', {}).get('timestamp', 0)
    age = (now - ts) // 86400 if ts else 0
    wt = item.get('working_tree', {}) or {}
    dirty = any(wt.get(k) for k in ('staged', 'modified', 'untracked', 'renamed', 'deleted'))
    remote = item.get('remote', {}) or {}
    has_remote = remote.get('name') is not None

    if state == 'integrated':
        print(f'REMOVE\t{mode}\t{ref}\t{display}\tmerged')
    elif (not has_remote) and (not dirty) and age > stale_age:
        print(f'REMOVE\t{mode}\t{ref}\t{display}\torphan-{age}d')
    elif age > aging_age:
        reasons = []
        if dirty:
            reasons.append('has uncommitted changes')
        if has_remote:
            reasons.append('still has remote')
        reason = '; '.join(reasons) if reasons else 'unclear state'
        print(f'AGING\t{mode}\t{ref}\t{display}\t{age}\t{reason}')
" 2>/dev/null
  ) || continue

  while IFS=$'\t' read -r kind mode ref display f5 f6; do
    [[ -z "$kind" ]] && continue
    if [[ "$kind" == "REMOVE" ]]; then
      reason="$f5"
      if [[ "$mode" == "BRANCH" ]]; then
        remove_ok() { $WT remove -f -y -C "$repo" "$ref" 2>/dev/null; }
      else
        remove_ok() { git -C "$repo" worktree remove --force "$ref" 2>/dev/null; }
      fi
      if remove_ok; then
        echo "$(now_ts) AUTO $repo_name $display removed ($reason)" >> "$LOG_FILE"
        removed+=("$repo_name|$display|$reason")
      else
        echo "$(now_ts) AUTO $repo_name $display remove-failed ($reason)" >> "$LOG_FILE"
      fi
    elif [[ "$kind" == "AGING" ]]; then
      age="$f5"
      reason="$f6"
      aging+=("$repo_name|$repo|$mode|$ref|$display|$age|$reason")
    fi
  done <<< "$tsv"
done

# Phase 3 output: build wt_prune_section (no top-level header — that lives in Phase 6)
wt_prune_section=""

if [[ ${#removed[@]} -gt 0 ]]; then
  noun="worktree"
  [[ ${#removed[@]} -gt 1 ]] && noun="worktrees"
  wt_prune_section+=":party-dumpster-fire: Auto-removed ${#removed[@]} $noun:"
  for entry in "${removed[@]}"; do
    IFS='|' read -r repo_name ref reason <<< "$entry"
    wt_prune_section+=$'\n'"  • \`$repo_name/$ref\` _($reason)_"
  done
fi

if [[ ${#aging[@]} -gt 0 ]]; then
  [[ -n "$wt_prune_section" ]] && wt_prune_section+=$'\n'
  wt_prune_section+=":old-man-with-walker: Aging (>${AGING_AGE_DAYS}d): ${#aging[@]}"
  for entry in "${aging[@]}"; do
    IFS='|' read -r repo_name repo_path mode ref display age reason <<< "$entry"
    short_reason="${reason//has uncommitted changes/dirty}"
    short_reason="${short_reason//still has remote/remote}"
    short_reason="${short_reason//; / + }"
    wt_prune_section+=$'\n'"  • \`$repo_name/$display\` _(${age}d, ${short_reason})_"
  done
  wt_prune_section+=$'\n\n'"[🧹 Triage aging worktrees](hammerspoon://wt-prune)"
fi

if [[ ${#removed[@]} -eq 0 && ${#aging[@]} -eq 0 ]]; then
  echo "$(now_ts) AUTO (nothing to prune)" >> "$LOG_FILE"
  wt_prune_section="No prunable worktrees and nothing aging. :sparkles:"
fi
fi

# Phase 4: daily-log generation
daily_log_status="skipped"
DAILY_LOG_PATH="$TARGET_FILE"

if [[ "$MODE" == "post" ]]; then
  if [[ -f "$DAILY_LOG_PATH" ]]; then
    daily_log_status="ok"
  else
    daily_log_status="failed"
    echo "$(now_ts) AUTO post-only requested but $DAILY_LOG_PATH is missing" >> "$DIGEST_LOG_DIR/daily-log.log"
  fi
fi

# Pre-flight claude auth check. A 7-minute Phase 4 spin-up that ends in 401 is
# the worst-case failure mode (recurring symptom on this machine: auth lapses
# silently). Confirm auth with a quick haiku call first; if it fails, skip
# Phase 4 entirely and surface "auth_expired" so the Slack section makes the
# fix obvious rather than misdiagnosing as a generation failure.
#
# Skipped entirely when AUTH_MODE=api-key — the ANTHROPIC_API_KEY env var is
# what `claude -p` will use, so the OAuth canary doesn't test anything useful.
# Timeout is 60s (not 15s) because cold-start `claude -p` post-wake can take
# >15s and was previously misreported as auth-expired.
if [[ "$MODE" != "post" && "$GAP_DAYS" -gt 0 ]]; then
  if [[ "$AUTH_MODE" == "api-key" ]]; then
    echo "$(now_ts) AUTO pre-flight skipped (mode=api-key)" >> "$DIGEST_LOG_DIR/daily-log.log"
  else
    echo "$(now_ts) AUTO pre-flight claude auth check (mode=$AUTH_MODE)..." >> "$DIGEST_LOG_DIR/daily-log.log"
    preflight_rc=0
    auth_check_output=$(timeout 60 "$CLAUDE" -p "ok" \
          --model haiku \
          --permission-mode bypassPermissions \
          --output-format json \
          </dev/null 2>&1) || preflight_rc=$?
    fail_reason=""
    if [[ "$preflight_rc" -eq 124 ]]; then
      daily_log_status="auth_expired"
      fail_reason="timed out after 60s (cold start?)"
    elif [[ "$preflight_rc" -ne 0 ]]; then
      daily_log_status="auth_expired"
      fail_reason="claude exited $preflight_rc"
    elif echo "$auth_check_output" | grep -qiE '401|invalid authentication|failed to authenticate'; then
      daily_log_status="auth_expired"
      fail_reason="401/auth error in response"
    fi

    if [[ "$daily_log_status" == "auth_expired" ]]; then
      {
        echo "$(now_ts) AUTO claude auth check FAILED ($fail_reason) — skipping Phase 4."
        echo "--- check output (first 5 lines) ---"
        echo "$auth_check_output" | head -n 5
      } >> "$DIGEST_LOG_DIR/daily-log.log"
    else
      echo "$(now_ts) AUTO claude auth check OK" >> "$DIGEST_LOG_DIR/daily-log.log"
    fi
  fi
fi

if [[ "$MODE" != "post" && "$GAP_DAYS" -gt 0 && "$daily_log_status" != "auth_expired" ]]; then
  if [[ "$GAP_DAYS" -eq 1 || "$GAP_DAYS" -ge 4 ]]; then
    DAILY_LOG_ARG="$TARGET_DATE"
  else
    DAILY_LOG_ARG="${GAP_DATES[0]} to $TARGET_DATE"
  fi

  trap 'echo "interrupted, killing children" >&2; pkill -P $$ 2>/dev/null; exit 130' INT TERM

  # The heavy daily-log call MUST be time-bounded AND retried. Headless
  # `claude -p` fails non-deterministically in two observed ways, neither
  # fixable from here: (1) an API/model hang that never returns (the unbounded
  # call once froze the cron past 2h), and (2) a mid-run wedge where claude
  # emits a tool_use and the tool-runner stalls before the tool_result ever
  # comes back, burning the whole timeout with zero further output (2026-06-01;
  # see memory/morning-digest-midrun-wedge.md). So we bound each attempt and
  # retry once: a transient wedge that used to guarantee a same-day miss now
  # recovers on attempt 2. We break the instant the target file exists, so a
  # successful attempt is never re-run. -k 30 escalates to SIGKILL if claude
  # ignores TERM. </dev/null avoids the "no stdin received in 3s" warning.
  #
  # Per-attempt timeout is 900s: comfortably above the ~7-8min worst case the
  # cron actually generates (a single day, or a 2-3 day range — a 4+ day gap
  # only generates the target date and defers the rest to the backfill script).
  # Worst case is 2x900s before the digest posts on a persistent wedge; that's
  # the deliberate tradeoff vs. a more invasive stall-watchdog.
  #
  # NOTE: do NOT add --strict-mcp-config with a redefined MCP allowlist here.
  # OAuth tokens for Slack/Linear/Granola are bound to their original plugin/
  # global server registration; redefining them in a custom --mcp-config orphans
  # the tokens and those sources come back unauthenticated (Glean-only log). The
  # daily-log call must inherit the normal server config so OAuth works.
  DAILY_LOG_TIMEOUT="${DAILY_LOG_TIMEOUT:-900}"
  DAILY_LOG_MAX_ATTEMPTS="${DAILY_LOG_MAX_ATTEMPTS:-2}"
  DAILY_LOG_PROMPT="/pkm:daily-log $DAILY_LOG_ARG

Non-interactive morning-digest cron run. Treat the date argument above as already approved. Do not ask follow-up questions about missing workday gaps. If the argument is a range, generate every workday in that range. If it is a single date and earlier workdays are missing, generate the requested date only."
  echo "$(now_ts) AUTO daily-log requested: $DAILY_LOG_ARG" >> "$DIGEST_LOG_DIR/daily-log.log"
  pipeline_ok=0
  attempt=1
  while [[ "$attempt" -le "$DAILY_LOG_MAX_ATTEMPTS" ]]; do
    [[ "$attempt" -gt 1 ]] && \
      echo "$(now_ts) AUTO daily-log retry (attempt $attempt/$DAILY_LOG_MAX_ATTEMPTS)" \
        >> "$DIGEST_LOG_DIR/daily-log.log"
    if timeout -k 30 "$DAILY_LOG_TIMEOUT" "$CLAUDE" -p "$DAILY_LOG_PROMPT" \
         --permission-mode bypassPermissions \
         --verbose --output-format stream-json \
         </dev/null \
         2>> "$DIGEST_LOG_DIR/daily-log.stderr.log" \
       | "$HOME/.claude/scripts/daily-log-backfill-progress.py" "$DIGEST_LOG_DIR/daily-log.jsonl" \
       >> "$DIGEST_LOG_DIR/daily-log.log"; then
      pipeline_ok=1
    else
      claude_rc="${PIPESTATUS[0]}"
      pipeline_ok=0
      if [[ "$claude_rc" -eq 124 || "$claude_rc" -eq 137 ]]; then
        echo "$(now_ts) AUTO daily-log claude call timed out after ${DAILY_LOG_TIMEOUT}s (rc=$claude_rc); killed (attempt $attempt/$DAILY_LOG_MAX_ATTEMPTS)" \
          >> "$DIGEST_LOG_DIR/daily-log.log"
      fi
    fi
    # File-existence is the source of truth: claude can write the log and still
    # exit nonzero. Once it's there, stop — never re-run a success.
    [[ -f "$DAILY_LOG_PATH" ]] && break
    attempt=$((attempt + 1))
  done

  # File-existence is the source of truth: claude can write the log and still
  # exit non-zero if the progress filter or final result frame falters. Fall
  # back to checking the file before declaring failure.
  if [[ -f "$DAILY_LOG_PATH" ]]; then
    daily_log_status="ok"
    if [[ "$pipeline_ok" -eq 0 ]]; then
      echo "$(now_ts) AUTO daily-log pipeline returned nonzero but $DAILY_LOG_PATH was written; treating as ok" \
        >> "$DIGEST_LOG_DIR/daily-log.log"
    fi
  else
    daily_log_status="failed"
    if [[ "$pipeline_ok" -eq 1 ]]; then
      echo "$(now_ts) AUTO daily-log generation completed but $DAILY_LOG_PATH missing" \
        >> "$DIGEST_LOG_DIR/daily-log.log"
    fi
  fi

  trap - INT TERM
fi

if [[ "$MODE" == "generate" ]]; then
  case "$daily_log_status" in
    ok|skipped) exit 0 ;;
    *) exit 1 ;;
  esac
fi

# --repost: file exists (validated above) and Phase 2 set GAP_DAYS=0, so Phase 4
# was a no-op. Force status="ok" so Phase 5 distillation runs against the existing
# file and the digest composes its happy-path daily_log_section.
if [[ "$REPOST" == "1" ]]; then
  daily_log_status="ok"
fi

# Phase 5: Slack distillation (Haiku model)
distillation=""
haiku=""

if [[ "$daily_log_status" == "ok" ]]; then
  distill_json=$("$CLAUDE" -p "Read $DAILY_LOG_PATH and return JSON with two fields:
  - 'distillation': a 1-2 sentence Slack-friendly summary of the Day at a Glance + Key Accomplishments sections
  - 'haiku': the three lines of haiku poetry from the file, joined with literal \n. Strip any markdown blockquote prefixes ('> ') — return only the poetry lines themselves.
Return ONLY valid JSON, no markdown fences." \
    --model haiku \
    --output-format json \
    --allowedTools "Read" \
    --permission-mode bypassPermissions \
    </dev/null \
    2>> "$DIGEST_LOG_DIR/distill.stderr.log") || distill_json=""

  if [[ -n "$distill_json" ]]; then
    # The agent's text response is in .result. Haiku model often wraps the inner
    # JSON in markdown fences despite prompt instructions — strip ```json/``` lines.
    # The `|| true` guards prevent set -e from aborting on jq parse failures.
    inner=$(echo "$distill_json" | jq -r '.result // empty' 2>/dev/null | sed -E '/^[[:space:]]*```/d' || true)
    if [[ -n "$inner" ]]; then
      distillation=$(echo "$inner" | jq -r '.distillation // empty' 2>/dev/null || true)
      haiku=$(echo "$inner" | jq -r '.haiku // empty' 2>/dev/null || true)
    fi
  fi

  if [[ -z "$distillation" || -z "$haiku" ]]; then
    echo "$(now_ts) AUTO distillation parse failed (see distill.stderr.log)" \
      >> "$DIGEST_LOG_DIR/daily-log.log"
    daily_log_status="failed"
  fi
fi

# Phase 7: PR review queue
# Numbered Phase 7 (not 6) so existing Phase 6 ("compose and post") keeps its
# label. Logically runs before Phase 6 because compose consumes pr_review_section.
pr_review_section=""
pr_review_status="ok"
PR_REVIEW_LOG="$DIGEST_LOG_DIR/pr-review.log"
if ! GITHUB_LOGIN=$(gh api user --jq .login 2>>"$PR_REVIEW_LOG"); then
  pr_review_status="failed"
  GITHUB_LOGIN=""
  echo "$(now_ts) AUTO pr-review login lookup failed" >> "$PR_REVIEW_LOG"
fi

pr_json=""
if [[ "$pr_review_status" == "ok" ]]; then
  if ! pr_json=$(gh search prs \
        --review-requested @me \
        --state open \
        --owner klaviyo \
        --json number,title,url,repository,author,updatedAt,isDraft \
        --limit 50 \
        2>>"$PR_REVIEW_LOG"); then
    pr_review_status="failed"
    echo "$(now_ts) AUTO pr-review gh search failed" >> "$PR_REVIEW_LOG"
  fi
fi

active=()
aging=()
if [[ "$pr_review_status" == "ok" ]]; then
  pr_tsv=$(jq -r '
    map(select(.author.type != "Bot"))
    | map(select(.isDraft == false))
    | map(
        . + {
          age_days: ((now - (.updatedAt | fromdateiso8601)) / 86400 | floor),
          repo_name: .repository.name,
          truncated_title: (
            if (.title | length) > 60
            then (.title[0:59] + "…")
            else .title
            end
          ),
          encoded_url: (.url | @uri)
        }
      )
    | map(. + { tier: (if .age_days <= 30 then "active" else "aging" end) })
    | sort_by(.updatedAt) | reverse
    | (map(select(.tier == "active")), map(select(.tier == "aging")))
    | .[]
    | [.tier, .repo_name, (.number | tostring), .truncated_title, .author.login, (.age_days | tostring), .encoded_url, .url]
    | @tsv
  ' <<<"$pr_json" 2>>"$PR_REVIEW_LOG") || pr_review_status="failed"
fi

if [[ "$pr_review_status" == "ok" && -n "$pr_tsv" ]]; then
  while IFS=$'\t' read -r tier repo_name num truncated_title author_login age_days encoded_url pr_url; do
    [[ -z "$tier" ]] && continue
    review_link="hammerspoon://tentacle?site=github-pr&mode=review&url=${encoded_url}"
    bullet="  • [${repo_name}#${num} - ${truncated_title}](${pr_url}) · ${author_login} · ${age_days}d · [🔍 review](${review_link})"
    if [[ "$tier" == "active" ]]; then
      active+=("$bullet")
    else
      aging+=("$bullet")
    fi
  done <<< "$pr_tsv"
fi

active_count=0
aging_count=0
[[ ${active+x} ]] && active_count=${#active[@]}
[[ ${aging+x} ]] && aging_count=${#aging[@]}

if [[ "$pr_review_status" == "ok" ]] && { [[ "$active_count" -gt 0 ]] || [[ "$aging_count" -gt 0 ]]; }; then
  if [[ "$active_count" -gt 0 ]]; then
    pr_review_section="📚 *PRs awaiting your review* ($active_count)"
    for bullet in "${active[@]}"; do
      pr_review_section+=$'\n'"$bullet"
    done
  else
    pr_review_section="📚 *PRs awaiting your review* (0 active)"
  fi

  if [[ "$aging_count" -gt 0 ]]; then
    aging_noun="stale review requests"
    [[ "$aging_count" -eq 1 ]] && aging_noun="stale review request"
    pr_review_section+=$'\n\n'":old-man-with-walker: $aging_count ${aging_noun} (>30d):"
    for bullet in "${aging[@]}"; do
      pr_review_section+=$'\n'"$bullet"
    done
  fi
fi

if [[ "$pr_review_status" == "failed" ]]; then
  pr_review_section="📚 *PRs awaiting your review*: fetch failed (see $PR_REVIEW_LOG)"
fi

# Phase 6: compose and post
daily_log_section=""
TARGET_FILENAME="$TARGET_FILENAME_DATE ($TARGET_DAY_SHORT).md"
TARGET_OBSIDIAN_URL="obsidian://open?vault=Obsidian%20Vault&file=Daily/$(url_encode_filename "$TARGET_FILENAME_DATE ($TARGET_DAY_SHORT)")"

case "$daily_log_status" in
  skipped)
    if [[ "$GAP_DAYS" -eq 0 ]]; then
      daily_log_section="📓 _${TARGET_DAY_LONG}'s log already present_"
    else
      daily_log_section="📓 *${TARGET_DAY_LONG}'s log* — generation skipped"
    fi
    ;;

  failed)
    daily_log_section="📓 *${TARGET_DAY_LONG}'s log* — generation failed (see $DIGEST_LOG_DIR/daily-log.log)"
    daily_log_section+=$'\n'"[🔍 Investigate log failure](hammerspoon://morning-digest-debug)"
    ;;

  auth_expired)
    daily_log_section="🔐 *Claude CLI auth expired* — daily-log skipped. Run \`claude /login\` then re-trigger \`~/.claude/scripts/morning-digest-cron.sh\`."
    ;;

  ok)
    daily_log_section="📓 [${TARGET_DAY_LONG}'s log — ${TARGET_FILENAME}](${TARGET_OBSIDIAN_URL})"
    daily_log_section+=$'\n'"   _${distillation}_"
    daily_log_section+=$'\n\n'

    while IFS= read -r line; do
      daily_log_section+="   > $line"$'\n'
    done <<< "$haiku"
    daily_log_section="${daily_log_section%$'\n'}"

    if [[ "$GAP_DAYS" -ge 2 && "$GAP_DAYS" -le 3 ]]; then
      daily_log_section+=$'\n\n'"   _Also backfilled:_"
      for d in "${GAP_DATES[@]:0:$((GAP_DAYS-1))}"; do
        d_short=$(date -j -f "%Y-%m-%d" "$d" "+%a")
        d_filename_date=$(date -j -f "%Y-%m-%d" "$d" "+%y-%m-%d")
        d_filename="$d_filename_date ($d_short).md"
        d_obsidian="obsidian://open?vault=Obsidian%20Vault&file=Daily/$(url_encode_filename "$d_filename_date ($d_short)")"
        daily_log_section+=$'\n'"   • [${d_filename}](${d_obsidian})"
      done
    elif [[ "$GAP_DAYS" -ge 4 ]]; then
      oldest="${GAP_DATES[0]}"
      newest_minus_one="${GAP_DATES[$((GAP_DAYS-2))]}"
      missing_count=$((GAP_DAYS-1))
      daily_log_section+=$'\n\n'"   ⚠️ _${missing_count} missing weekday entries detected (${oldest} to ${newest_minus_one})."
      daily_log_section+=$'\n'"   Run \`~/.claude/scripts/daily-log-backfill.sh\` to catch up._"
    fi
    ;;
esac

# Phase 5.5: MCP health check for OAuth-dependent sources.
# Slack/Linear/Granola authenticate via OAuth tokens that can lapse and need an
# interactive `/mcp` re-auth a headless cron cannot perform. We can't prevent a
# lapse, but we refuse to fail SILENTLY: check each server's connection status
# and, if any is down, prepend a loud banner to the digest naming what needs
# re-auth. `claude mcp get` reports a deterministic "✓ Connected" vs "Needs
# authentication" — no LLM guesswork (an agent-judged probe false-FAILed a
# healthy Linear in testing). Mirrors the Anthropic auth-canary pattern.
# NOTE: /bin/bash on macOS is 3.2 — no associative arrays; iterate label:server
# pairs and split on the first colon (server names themselves contain colons).
mcp_health_banner=""
if [[ "$daily_log_status" != "auth_expired" ]]; then
  down=()
  for pair in "slack:plugin:slack:slack" "linear:plugin:linear:linear" "granola:granola"; do
    label="${pair%%:*}"
    server="${pair#*:}"
    status_out=$(timeout -k 5 60 "$CLAUDE" mcp get "$server" 2>/dev/null || true)
    echo "$status_out" | grep -q "Connected" || down+=("$label")
  done
  if [[ ${#down[@]} -gt 0 ]]; then
    mcp_health_banner=":warning: *MCP re-auth needed* — ${down[*]} unavailable, so today's log is missing those sources. Run \`/mcp\` and reconnect, then re-trigger the digest."
    echo "$(now_ts) AUTO MCP-HEALTH down: ${down[*]}" >> "$DIGEST_LOG_DIR/daily-log.log"
  else
    echo "$(now_ts) AUTO MCP-HEALTH all OK" >> "$DIGEST_LOG_DIR/daily-log.log"
  fi
fi

# Compose unified message
HEADER="*Morning digest ($(date +%Y-%m-%d))*"

sections=()
[[ -n "$daily_log_section" ]]  && sections+=("$daily_log_section")
[[ -n "$pr_review_section" ]]  && sections+=("$pr_review_section")
[[ -n "$wt_prune_section" ]]   && sections+=("$wt_prune_section")

SEPARATOR=$'\n\n──────────────\n\n'
joined=""
for i in "${!sections[@]}"; do
  if [[ "$i" -eq 0 ]]; then
    joined="${sections[$i]}"
  else
    joined+="${SEPARATOR}${sections[$i]}"
  fi
done

final_message="${HEADER}"$'\n\n'
[[ -n "$mcp_health_banner" ]] && final_message+="${mcp_health_banner}"$'\n\n'
final_message+="${joined}"

notify_slack "$final_message"

exit 0
