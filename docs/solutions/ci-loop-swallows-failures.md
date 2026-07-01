---
module: ci
tags: [github-actions, bash, exit-code, for-loop, silent-failure]
problem_type: gotcha
date: 2026-07-01
---

## Problem

The CI "bash syntax check" step looped over every script with
`for f in ...; do bash -n "$f" && echo "ok: $f"; done` and stayed green even when a
script had a syntax error. A broken `bin/` script could land on main with CI passing.

## Cause

A shell step's exit status is the status of its **last** command. Inside the loop,
`bash -n "$f" && echo ok` swallows each failure (the `&&` chain just skips the echo),
so only the final iteration's status can fail the step — every earlier error is lost.

## Fix

Track failures explicitly and exit with the aggregate:

```bash
status=0
for f in bin/* tests/*.sh; do
  [ -f "$f" ] || continue
  if bash -n "$f"; then echo "ok: $f"; else echo "SYNTAX ERROR: $f"; status=1; fi
done
exit "$status"
```

Same trap applies to any "check each file" loop (lint, grep guards). If the loop must
stop at the first error, `bash -n "$f" || exit 1` also works.
