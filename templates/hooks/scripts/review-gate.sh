#!/bin/bash
# PreToolUse (Bash) review gate — BLOCKS `git commit` until a review marker
# exists for this session. The point: make "was this actually reviewed?" a hard
# gate instead of a convention an agent can skip past (STANDARD.md §2,
# "Compile, don't retrieve" — promote a rule into a hook that blocks, not flags).
#
# How it works: a code review (your /code-review, a reviewer agent, whatever)
# writes a marker file on PASS; this hook checks the marker before letting the
# commit through. Markers are session-scoped so parallel agent sessions in the
# same repo don't clear each other's gate.
#
# Wire it up (in .claude/settings.json or the plugin hooks.json):
#   PreToolUse matcher "Bash" -> command: bash .../review-gate.sh
# And have your review step write the marker on PASS:
#   bash .../review-gate.sh --pass code-reviewed
#
# Bypass one commit (genuine exception): touch the marker yourself, or set
#   REVIEW_GATE_OFF=1  in the environment.
#
# Per-repo: edit SCOPED_PATTERNS below to require a stricter review for the
# paths that need it (migrations, core modules, generated specs, ...).

set -uo pipefail

# Session-scoped marker dir. Same repo + same session = same gate.
marker_dir() {
  local root hash session
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  # Portable short hash: shasum (macOS) or sha256sum (Linux).
  hash="$(printf '%s' "$root" | { shasum -a 256 2>/dev/null || sha256sum; } | cut -c1-12)"
  session="${CLAUDE_SESSION_ID:-default}"
  printf '%s/review-gate/%s/%s' "${TMPDIR:-/tmp}" "$hash" "$session"
}

# --- Marker writer: `review-gate.sh --pass <name>` --------------------------
# Call this from your review step once it passes. Default name: code-reviewed.
if [ "${1:-}" = "--pass" ]; then
  dir="$(marker_dir)"
  mkdir -p "$dir"
  : > "$dir/${2:-code-reviewed}"
  echo "review-gate: marked ${2:-code-reviewed} PASS for this session" >&2
  exit 0
fi

# Explicit off-switch for a sanctioned exception.
[ -n "${REVIEW_GATE_OFF:-}" ] && exit 0

# --- Gate mode (PreToolUse): read the tool payload from stdin ---------------
payload="$(cat)"
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')"
else
  # jq-less fallback: pull the first "command":"..." value.
  cmd="$(printf '%s' "$payload" \
    | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
    | sed 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
fi

# Only gate git commits; let everything else pass untouched.
case "${cmd:-}" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

dir="$(marker_dir)"
blocked=0

block() {
  echo "" >&2
  echo "  BLOCKED: $1 required before commit (STANDARD.md §2, §5)" >&2
  echo "  Run the review, then retry the commit." >&2
  echo "  Bypass a genuine exception: REVIEW_GATE_OFF=1 git commit ..." >&2
  blocked=1
}

# Always require a code review.
[ -f "$dir/code-reviewed" ] || block "code review"

# Stricter marker only when the staged diff touches sensitive paths. Edit the
# pattern for this repo; empty pattern = no scoped requirement.
SCOPED_PATTERNS='(migrations/|schema/).*'
if [ -n "$SCOPED_PATTERNS" ]; then
  if git diff --cached --name-only 2>/dev/null | grep -qE "$SCOPED_PATTERNS"; then
    [ -f "$dir/deep-reviewed" ] || block "deep review (sensitive paths changed)"
  fi
fi

# Exit 2 signals the driver to block the tool call (PreToolUse convention).
[ "$blocked" -eq 0 ] || exit 2
exit 0
