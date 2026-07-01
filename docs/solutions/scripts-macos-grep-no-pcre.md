---
module: bin
tags: [macos, bsd, grep, pcre, portability, awk]
problem_type: gotcha
date: 2026-07-01
---

## Problem

`pr-risk learn` used `grep -vP "\t${sig}$"` to rewrite its pattern log. On macOS the
command errors (`grep: invalid option -- P`), so the script fell through to a fragile
fallback, and any similar use without a fallback would silently corrupt the log.

## Cause

`-P` (PCRE) is a GNU grep extension. macOS ships BSD grep, which has no PCRE support
at all — the flag is a hard error, not a degraded mode. `\t` inside a plain grep
pattern is also not portable.

## Fix

Use `awk` for field-based filtering — it is POSIX and identical on both platforms:

```bash
awk -F'\t' -v s="$sig" '$2!=s' "$LOG" > "$LOG.tmp"
```

House rule (now in AGENTS.md conventions): no GNU-only flags in `bin/`. The same
class of bug applies to `stat -c` (GNU) vs `stat -f` (BSD) — see
`templates/hooks/scripts/check-config.sh` for the dual-form pattern.
