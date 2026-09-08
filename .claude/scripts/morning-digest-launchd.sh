#!/bin/bash
set -u

SCRIPT="$HOME/.claude/scripts/morning-digest-cron.sh"
DIGEST_LOG_DIR="$HOME/.local/share/morning-digest"
LOCK_DIR="$DIGEST_LOG_DIR/launchd.lock"
mkdir -p "$DIGEST_LOG_DIR"

now_ts() { date -u +"%Y-%m-%dT%H:%M:%S"; }

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "$(now_ts) launchd wrapper already running; exiting" >> "$DIGEST_LOG_DIR/launchd-wrapper.log"
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

echo "$(now_ts) launchd wrapper start" >> "$DIGEST_LOG_DIR/launchd-wrapper.log"

"$SCRIPT" --generate-only \
  >> "$DIGEST_LOG_DIR/generate-only.stdout.log" \
  2>> "$DIGEST_LOG_DIR/generate-only.stderr.log"
generate_rc=$?
echo "$(now_ts) generate-only rc=$generate_rc" >> "$DIGEST_LOG_DIR/launchd-wrapper.log"

"$SCRIPT" --post-only \
  >> "$DIGEST_LOG_DIR/post-only.stdout.log" \
  2>> "$DIGEST_LOG_DIR/post-only.stderr.log"
post_rc=$?
echo "$(now_ts) post-only rc=$post_rc" >> "$DIGEST_LOG_DIR/launchd-wrapper.log"

if [[ "$generate_rc" -ne 0 || "$post_rc" -ne 0 ]]; then
  echo "$(now_ts) launchd wrapper failed generate=$generate_rc post=$post_rc" >> "$DIGEST_LOG_DIR/launchd-wrapper.log"
  exit 1
fi

echo "$(now_ts) launchd wrapper ok" >> "$DIGEST_LOG_DIR/launchd-wrapper.log"
exit 0
