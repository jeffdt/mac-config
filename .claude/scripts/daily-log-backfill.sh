#!/bin/bash
set -euo pipefail

# daily-log-backfill.sh: Manual one-shot backfill for missed daily dev log
# entries. Detects the gap between the most recent ~/o/Daily/ entry and
# yesterday, splits it into Mon-Fri chunks, and drives /pkm:daily-log
# headlessly (one chunk at a time) using --output-format stream-json so we
# can render live progress to the terminal. Aborts on the first failure;
# rerun to pick up where it left off (gap detection is idempotent).

CLAUDE="$HOME/.local/bin/claude"
DAILY_DIR="$HOME/o/Daily"
LOG_DIR="$HOME/.local/share/daily-log"
LOGFILE="$LOG_DIR/backfill-$(date +%Y%m%d-%H%M%S).log"
PROGRESS="$HOME/.claude/scripts/daily-log-backfill-progress.py"

# Treat a chunk that exits 0 in under this many seconds with no file writes
# as a transient fast-fail (the "Execution error" signature). One retry.
FAST_FAIL_SECS=60

mkdir -p "$LOG_DIR"

cleanup() {
  local code=${1:-130}
  echo
  echo "Interrupted. Killing any child claude processes..."
  pkill -P $$ 2>/dev/null || true
  sleep 1
  pkill -9 -P $$ 2>/dev/null || true
  exit "$code"
}
trap 'cleanup 130' INT
trap 'cleanup 143' TERM
trap 'pkill -P $$ 2>/dev/null || true' EXIT

add_days() {
  local d=$1 n=$2
  local sign="+"
  if [[ "$n" -lt 0 ]]; then
    sign="-"
    n=${n#-}
  fi
  date -j -v"${sign}${n}"d -f "%Y-%m-%d" "$d" +%Y-%m-%d
}

count_files_in_range() {
  local cs=$1 ce=$2
  local count=0
  local d=$cs
  while [[ ! "$d" > "$ce" ]]; do
    local dow
    dow=$(date -j -f "%Y-%m-%d" "$d" +%u)
    if [[ "$dow" -lt 6 ]]; then
      local filename
      filename=$(date -j -f "%Y-%m-%d" "$d" "+%y-%m-%d (%a).md")
      if [[ -f "$DAILY_DIR/$filename" ]]; then
        count=$((count + 1))
      fi
    fi
    d=$(add_days "$d" 1)
  done
  echo "$count"
}

count_workdays_in_range() {
  local cs=$1 ce=$2
  local count=0
  local d=$cs
  while [[ ! "$d" > "$ce" ]]; do
    local dow
    dow=$(date -j -f "%Y-%m-%d" "$d" +%u)
    if [[ "$dow" -lt 6 ]]; then
      count=$((count + 1))
    fi
    d=$(add_days "$d" 1)
  done
  echo "$count"
}


if [[ ! -x "$CLAUDE" ]]; then
  echo "claude binary not found at $CLAUDE" >&2
  exit 2
fi

if [[ ! -d "$DAILY_DIR" ]]; then
  echo "daily directory $DAILY_DIR does not exist" >&2
  exit 2
fi

if [[ ! -x "$PROGRESS" ]]; then
  echo "progress filter not executable at $PROGRESS" >&2
  exit 2
fi

LATEST_RAW=$(
  find "$DAILY_DIR" -maxdepth 1 -name '[0-9][0-9]-[0-9][0-9]-[0-9][0-9] (*).md' -print 2>/dev/null \
    | xargs -n1 basename 2>/dev/null \
    | grep -oE '^[0-9]{2}-[0-9]{2}-[0-9]{2}' \
    | sort -r \
    | head -n1
)

if [[ -z "$LATEST_RAW" ]]; then
  echo "no existing entries in $DAILY_DIR; backfill needs a starting point" >&2
  exit 2
fi

LATEST="20${LATEST_RAW}"
START=$(add_days "$LATEST" 1)
END=$(date -v-1d +%Y-%m-%d)

if [[ "$START" > "$END" ]]; then
  echo "Already caught up through $END."
  exit 0
fi

start_dow=$(date -j -f "%Y-%m-%d" "$START" +%u)
days_back=$((start_dow - 1))
cursor=$(add_days "$START" "-$days_back")

chunk_starts=()
chunk_ends=()

while [[ ! "$cursor" > "$END" ]]; do
  cs=$cursor
  if [[ "$cs" < "$START" ]]; then
    cs=$START
  fi
  friday=$(add_days "$cursor" 4)
  ce=$friday
  if [[ "$ce" > "$END" ]]; then
    ce=$END
  fi
  if [[ ! "$cs" > "$ce" ]]; then
    chunk_starts+=("$cs")
    chunk_ends+=("$ce")
  fi
  cursor=$(add_days "$cursor" 7)
done

M=${#chunk_starts[@]}

if [[ "$M" -eq 0 ]]; then
  echo "Already caught up through $END."
  exit 0
fi

echo "Backfilling $LATEST → $END across $M chunk(s)."
echo "Logfile: $LOGFILE"

TOTAL_DAYS=0

for ((i=0; i<M; i++)); do
  cs=${chunk_starts[i]}
  ce=${chunk_ends[i]}
  n=$((i + 1))
  expected=$(count_workdays_in_range "$cs" "$ce")
  before=$(count_files_in_range "$cs" "$ce")

  echo
  echo "→ Chunk $n/$M: $cs to $ce ($expected workday(s))"
  echo

  attempt=1
  while :; do
    start_ts=$(date +%s)
    set +e
    "$CLAUDE" -p "/pkm:daily-log $cs to $ce" \
      --permission-mode bypassPermissions \
      --verbose --output-format stream-json 2>&1 \
      | python3 "$PROGRESS" "$LOGFILE"
    rc=${PIPESTATUS[0]}
    set -e
    end_ts=$(date +%s)
    elapsed=$((end_ts - start_ts))

    after=$(count_files_in_range "$cs" "$ce")
    written=$((after - before))

    if [[ "$rc" -ne 0 ]]; then
      echo
      echo "✗ Chunk $n/$M exited $rc after ${elapsed}s (see $LOGFILE)"
      exit 1
    fi

    if [[ "$written" -ge "$expected" ]]; then
      break
    fi

    # Fast-fail signature: short runtime + no new files. Retry once.
    if [[ "$attempt" -eq 1 && "$elapsed" -lt "$FAST_FAIL_SECS" && "$written" -eq 0 ]]; then
      echo
      echo "⚠ Chunk $n/$M exited 0 in ${elapsed}s with no files written (likely transient). Retrying..."
      attempt=2
      before=$after
      continue
    fi

    echo
    echo "✗ Chunk $n/$M wrote $written/$expected files after ${elapsed}s (see $LOGFILE)"
    exit 1
  done

  echo
  echo "✓ Chunk $n/$M complete (${elapsed}s, $written file(s) written)"

  d=$cs
  while [[ ! "$d" > "$ce" ]]; do
    dow=$(date -j -f "%Y-%m-%d" "$d" +%u)
    if [[ "$dow" -lt 6 ]]; then
      abbrev=$(date -j -f "%Y-%m-%d" "$d" +%a)
      filename=$(date -j -f "%Y-%m-%d" "$d" "+%y-%m-%d (%a).md")
      filepath="$DAILY_DIR/$filename"
      if [[ -f "$filepath" ]]; then
        haiku=$(awk '
          /^# Haiku/ { flag=1; next }
          /^___/ { if (flag) exit }
          flag && /^> / {
            sub(/^> /, "")
            printf "%s%s", sep, $0
            sep=" / "
          }
        ' "$filepath")
        if [[ -z "$haiku" ]]; then
          haiku="(no haiku found)"
        fi
        echo "  $abbrev: $haiku"
        TOTAL_DAYS=$((TOTAL_DAYS + 1))
      else
        echo "  $abbrev: (file missing)"
      fi
    fi
    d=$(add_days "$d" 1)
  done
done

echo
echo "Generated $TOTAL_DAYS entries across $M chunks."
echo "Logfile: $LOGFILE"
