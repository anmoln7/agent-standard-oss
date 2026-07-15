#!/bin/bash
# Debt ratchet — a non-increasing gate for metrics you want to shrink over time
# without blocking on the backlog you already have (STANDARD.md §2). Instead of
# an absolute rule ("no file over 500 lines") that a repo full of 600-line files
# can never satisfy, you snapshot today's numbers as a baseline and fail CI only
# when a metric *goes up*. Existing debt is grandfathered; new debt is blocked;
# lowering the baseline is a deliberate commit.
#
#   ratchet.sh snapshot [baseline]   # write current metrics as the new baseline
#   ratchet.sh check    [baseline]   # fail (exit 1) if any metric exceeds baseline
#   ratchet.sh show                  # print current metrics, compare nothing
#
# baseline defaults to .ci/ratchet-baseline.env (commit it).
#
# Per-repo: edit collect_metrics() for the debt THIS repo wants to ratchet down.
# The examples below are language-agnostic; replace/extend them.

set -uo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
MODE="${1:-check}"
BASELINE="${2:-.ci/ratchet-baseline.env}"
case "$BASELINE" in /*) : ;; *) BASELINE="$ROOT/$BASELINE" ;; esac

# --- Define the metrics to ratchet (EDIT for this repo) ---------------------
# Each line: KEY=<count>. Lower is better; the gate fails if current > baseline.
collect_metrics() {
  local big todo
  # Example 1: source files over 500 lines (structural debt).
  big="$(find "$ROOT" -type f \( -name '*.py' -o -name '*.js' -o -name '*.ts' \
           -o -name '*.go' -o -name '*.rs' \) \
         -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null \
       | while IFS= read -r f; do
           [ "$(wc -l < "$f" 2>/dev/null || echo 0)" -gt 500 ] && echo x
         done | grep -c x || true)"
  # Example 2: lingering TODO/FIXME markers in tracked source.
  todo="$(git -C "$ROOT" grep -rIn -e 'TODO' -e 'FIXME' -- \
            '*.py' '*.js' '*.ts' '*.go' '*.rs' 2>/dev/null | grep -c . || true)"
  printf 'FILES_GT_500=%s\n' "${big:-0}"
  printf 'TODO_FIXME=%s\n'   "${todo:-0}"
}

val() { grep -E "^$2=" "$1" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '[:space:]'; }

case "$MODE" in
  snapshot)
    mkdir -p "$(dirname "$BASELINE")"
    { echo "# ratchet baseline — regenerate deliberately, never to hide a regression"; \
      collect_metrics; } > "$BASELINE"
    echo "ratchet: wrote baseline $BASELINE"; grep -v '^#' "$BASELINE"
    ;;
  show)
    collect_metrics
    ;;
  check)
    if [ ! -f "$BASELINE" ]; then
      echo "ratchet: no baseline at $BASELINE — create one:" >&2
      echo "  bash $0 snapshot" >&2
      exit 1
    fi
    cur="$(mktemp)"; collect_metrics > "$cur"
    failed=0
    while IFS='=' read -r key _; do
      case "$key" in ''|\#*) continue ;; esac
      b="$(val "$BASELINE" "$key")"; c="$(val "$cur" "$key")"
      if [ -z "$b" ] || [ -z "$c" ]; then
        echo "  FAIL $key: missing in baseline or current"; failed=1; continue
      fi
      if [ "$c" -gt "$b" ]; then
        echo "  FAIL $key: baseline=$b current=$c (went up)"; failed=1
      else
        echo "  OK   $key: baseline=$b current=$c"
      fi
    done < "$cur"
    rm -f "$cur"
    if [ "$failed" -ne 0 ]; then
      echo "" >&2
      echo "Debt increased. Reduce it, or update the baseline on purpose:" >&2
      echo "  bash $0 snapshot" >&2
      exit 1
    fi
    ;;
  *)
    echo "usage: $0 {snapshot|check|show} [baseline]" >&2; exit 2
    ;;
esac
