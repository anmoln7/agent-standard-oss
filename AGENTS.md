# agent-standard-oss: Agent Guide

A house standard (spec + bash scripts + templates) that keeps AI-agent instruction
files honest and single-sourced. This repo eats its own dog food: this file follows
the skeleton in [STANDARD.md §1](STANDARD.md#1-one-source-of-truth).

## Architecture

- `STANDARD.md` — the spec. Eleven numbered sections; everything else serves it.
- `bin/` — standalone bash scripts, no runtime deps. Each is self-contained except
  `land-safely`, `pr-approve`, and `crew`, which call sibling scripts via their own
  resolved directory (`SELF_DIR`), never via `PATH`. `adopt` (the onboarding wizard)
  also resolves `../templates` the same way, so `bin/` must stay next to `templates/`.
  `sync-version` is a maintainer script (not a user-facing command): it derives the
  version from the root `VERSION` file into the plugin manifests and README pin.
- `VERSION` — single source of truth for the release version; `bin/sync-version`
  writes it into the two `.claude-plugin/*.json` files and the README CI-example pin.
- `templates/` — files users copy into their repos (hooks, gitignore, fix-log example).
- `examples/AGENTS.md` — a worked example for a fictional repo; keep it in lockstep
  with the skeleton in STANDARD.md.
- `tests/run-tests.sh` — plain-bash tests; no bats, no framework.
- `action.yml` — the repo doubles as a composite GitHub Action that runs
  `adopt --check` in a consumer's checkout; CI dogfoods it (`uses: ./`).
- `install.sh` — the `curl | bash` one-liner; must stay fully non-interactive
  (stdin is the pipe) and touch nothing outside `$HOME`.
- `.claude-plugin/` + `commands/` — the repo is also a Claude Code plugin
  (`/agent-standard:adopt`, `/agent-standard:check`); commands reach the scripts
  via `${CLAUDE_PLUGIN_ROOT}/bin/`.
- `.github/workflows/pages.yml` + `.github/pages.css` — pandoc-built site
  (STANDARD.md + ADOPTERS.md) deployed to anmoln7.github.io/agent-standard-oss.
- `.gitattributes` — forces LF on every text file (`* text=auto eol=lf`) so a CRLF
  checkout (e.g. Windows) can't break `bin/`, `install.sh`, or the test suite;
  CI's CRLF check backs it up.

## Commands

```bash
tests/run-tests.sh                    # the test suite (isolated HOME + temp repos)
bash -n bin/* install.sh              # syntax check
shellcheck -S warning bin/* install.sh tests/*.sh templates/hooks/scripts/*.sh templates/git/hooks/pre-commit
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
- Tag a release → edit the `VERSION` file and run `bin/sync-version`; it derives the
  version into `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and the
  README "Enforce it in CI" pin. CI runs `sync-version --check` to catch any hand-edit
  that drifts from `VERSION`.
- Workflow `uses:` lines stay pinned to a commit SHA with a `# vN` comment — never a
  bare mutable tag.
- Change the AGENTS.md skeleton in STANDARD.md §1 → update `examples/AGENTS.md` (and this file).
- Add/rename a STANDARD.md section → update the README "About" bullets (both lists
  link to sections by anchor, so a renamed heading breaks its link).
- Add a CI gate → mention it in CONTRIBUTING's script rules.
- Add a fix-log frontmatter field in STANDARD.md §2 → update `templates/docs/solutions/EXAMPLE-*.md`.
- `.gitattributes` forces LF on every text file via a blanket `* text=auto eol=lf`,
  so a new script under any path is covered automatically — no per-path pattern to add.

## Commit flow

Default: commit and push straight to `main` (per STANDARD.md §6). Branch + PR only for
risky changes. Tag releases (`vX.Y.Z`) and add a CHANGELOG entry.
