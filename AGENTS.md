# agent-standard-oss: Agent Guide

A house standard (spec + bash scripts + templates) that keeps AI-agent instruction
files honest and single-sourced. This repo eats its own dog food: this file follows
the skeleton in [STANDARD.md §1](STANDARD.md#1-one-source-of-truth).

## Architecture

- `STANDARD.md` — the spec. Seven numbered sections; everything else serves it.
- `bin/` — standalone bash scripts, no runtime deps. Each is self-contained except
  `land-safely`, `pr-approve`, and `crew`, which call sibling scripts via their own
  resolved directory (`SELF_DIR`), never via `PATH`. `adopt` (the onboarding wizard)
  also resolves `../templates` the same way, so `bin/` must stay next to `templates/`.
- `templates/` — files users copy into their repos (hooks, gitignore, fix-log example).
- `examples/AGENTS.md` — a worked example for a fictional repo; keep it in lockstep
  with the skeleton in STANDARD.md.
- `tests/run-tests.sh` — plain-bash tests; no bats, no framework.

## Commands

```bash
tests/run-tests.sh                    # the test suite (isolated HOME + temp repos)
bash -n bin/*                         # syntax check
shellcheck -S warning bin/* tests/*.sh templates/hooks/scripts/*.sh templates/git/hooks/pre-commit
```

## Conventions

- bash only, no runtime deps. Target macOS *and* Linux: no GNU-only flags
  (no `grep -P`, prefer `awk`; `stat -c` needs a BSD `stat -f` fallback).
- Config over hardcoding: paths/roots come from env vars with defaults
  (`AGENT_STD_ROOTS`), never a personal path. CI greps for personal config and fails.
- Read-only by default: audit/report scripts must not mutate a repo; anything that
  writes says so in its header.

## Gotchas

The traps. (Full past-incident write-ups live in [`docs/solutions/`](docs/solutions/).)

- Scripts use `set -uo pipefail` **without** `-e` — a failing command does NOT abort.
  Anything that must gate has to check its exit code explicitly (see `gate()` in
  `land-safely`, and `docs/solutions/scripts-gates-need-explicit-exit-checks.md`).
- A `for f in ...; do check "$f" && echo ok; done` loop in CI reports only the LAST
  iteration's status. See `docs/solutions/ci-loop-swallows-failures.md`.

## Before shipping

`tests/run-tests.sh` passes, `shellcheck -S warning` is clean on every script, and
nothing personal (email, org id, token, private repo name) appears in the diff — CI
enforces all three.

## Keep in sync

- Add/rename a `bin/` script → update the README "What's in the box" tree and CHANGELOG.
- Change the AGENTS.md skeleton in STANDARD.md §1 → update `examples/AGENTS.md` (and this file).
- Add a CI gate → mention it in CONTRIBUTING's script rules.
- Add a fix-log frontmatter field in STANDARD.md §2 → update `templates/docs/solutions/EXAMPLE-*.md`.

## Commit flow

Default: commit and push straight to `main` (per STANDARD.md §6). Branch + PR only for
risky changes. Tag releases (`vX.Y.Z`) and add a CHANGELOG entry.
