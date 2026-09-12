#!/bin/bash
# guard-large-read.sh — a PreToolUse hook that blocks whole-file dumps of large
# files into context, on BOTH surfaces that reach the same capability:
#   - the Read tool (matcher: Read)
#   - the cat/head/tail/less/more bash path (matcher: Bash)
# Guarding only Read leaves the shell path as a trivial bypass (STANDARD.md §2).
#
# Read-only: it decides allow/block, never edits a file. It reads the hook
# payload on stdin (JSON) and writes an allow/block decision on stdout.
#
# Wire it up in hooks.json against both tools, e.g.:
#   { "matcher": "Read", "hooks": [{ "type": "command",
#       "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/hooks/scripts/guard-large-read.sh\"" }] }
#   { "matcher": "Bash", "hooks": [{ "type": "command",
#       "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/hooks/scripts/guard-large-read.sh\"" }] }
#
# Tune the threshold with GUARD_MAX_LINES (default 350). Replace the redirect
# message with whatever you want the agent to do instead (a delegation skill, a
# targeted re-read); the point of the standard is the two-surface guard, not the
# specific redirect.
#
# Requires: jq.
set -uo pipefail

MAX_LINES="${GUARD_MAX_LINES:-350}"
case "$MAX_LINES" in ''|*[!0-9]*) MAX_LINES=350 ;; esac

allow()  { echo '{"decision": "allow"}'; exit 0; }
block()  { # block <lines>
  printf '{"decision": "block", "reason": "File is %s lines (threshold: %s). Read only the section you need (Read with an offset/limit, or grep first), or delegate the bulk read — do not dump the whole file into context."}\n' "$1" "$MAX_LINES"
  exit 0
}

command -v jq >/dev/null 2>&1 || allow   # no jq: fail open, never wedge the agent

input="$(cat)"
tool="$(printf '%s' "$input" | jq -r '.tool_name // empty')"

# how many lines is $1, or -1 if it isn't a readable regular file
count_lines() {
  [ -n "$1" ] && [ -f "$1" ] || { echo -1; return; }
  wc -l < "$1" 2>/dev/null | tr -d ' ' || echo -1
}

case "$tool" in
  Read|"")   # "" covers hosts that match on Read without setting tool_name
    file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
    offset="$(printf '%s' "$input" | jq -r '.tool_input.offset // empty')"
    limit="$(printf '%s' "$input" | jq -r '.tool_input.limit // empty')"
    # a targeted read already knows what it wants — let it through
    [ -n "$offset" ] || [ -n "$limit" ] && allow
    lines="$(count_lines "$file_path")"
    [ "$lines" -le "$MAX_LINES" ] && allow
    block "$lines"
    ;;

  Bash)
    cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
    [ -z "$cmd" ] && allow
    # a pipe or redirect is a targeted read, not a dump into context
    printf '%s' "$cmd" | grep -qE '[|>]' && allow
    # only guard a bare cat/head/tail/less/more <file>
    printf '%s' "$cmd" | grep -qE '^[[:space:]]*(cat|head|tail|less|more)[[:space:]]' || allow
    # head/tail with a line count is a targeted read (the shell's offset/limit) —
    # let it through, same as a Read with a limit. -n N, -N, --lines=N.
    printf '%s' "$cmd" | grep -qE '^[[:space:]]*(head|tail)[[:space:]]' \
      && printf '%s' "$cmd" | grep -qE '(-n[[:space:]]*[0-9]|-[0-9]|--lines)' && allow
    args="$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]*(cat|head|tail|less|more)[[:space:]]+//')"
    file_path=""
    for arg in $args; do
      case "$arg" in
        -*) continue ;;                              # skip flags (-n, -100, --number)
        *)  file_path="$(printf '%s' "$arg" | tr -d "\"'")"; break ;;
      esac
    done
    lines="$(count_lines "$file_path")"
    [ "$lines" -gt "$MAX_LINES" ] && block "$lines"
    allow
    ;;

  *) allow ;;   # any other tool: not our surface
esac
