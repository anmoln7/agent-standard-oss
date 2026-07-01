---
module: bin
tags: [bash, set-e, exit-code, land-safely, gate, silent-failure]
problem_type: bug
date: 2026-07-01
---

## Problem

`land-safely` documented steps 4–5 (secret scan, tests, lint) as "gates", but a repo
with failing `npm test` still got pushed and could even auto-merge: the script ran the
tests, printed the failure, and carried on to `git push` + `gh pr create`.

## Cause

The scripts use `set -uo pipefail` **without** `-e`, so a nonzero exit does not stop
execution. `run npm test --silent` invoked the tests but nothing looked at the exit
code. "Gate" was only true in the comments.

## Fix

A gate must check its own exit code. `land-safely` now wraps gating steps in:

```bash
gate(){ run "$@" || { echo "🛑 gate failed: $*  — aborting before push."; exit 1; }; }
```

Regression-pinned by `tests/run-tests.sh` ("land-safely aborts when npm test fails" /
"nothing was pushed to the remote"). When adding any step described as a gate, add the
explicit check — don't rely on `set -e`, which these scripts deliberately don't use.
