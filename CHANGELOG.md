# Changelog

All notable changes to agent-standard are documented here. Versions follow
`MAJOR.MINOR.PATCH`.

## [0.2.0] - 2026-07-01

The repo now passes its own audit, and every "gate" actually gates.

### Fixed

- **land-safely**: test/lint/secret gates now abort the pipeline on failure — before,
  a repo with failing tests was still pushed and could auto-merge (scripts run without
  `set -e`, and nothing checked the exit codes). `pr-risk classify` also runs once
  instead of twice, and the header no longer claims a full-history scan for what is a
  branch-diff scan.
- **wt / crew**: handed-out worktrees are now *claimed* until `wt free`, so parallel
  `crew` tasks can no longer be assigned the same worktree (a just-claimed tree is
  still clean, so the old "no uncommitted changes" idle test raced).
- **pr-risk**: `learn` no longer uses GNU-only `grep -P`, which is a hard error on
  macOS BSD grep; the pattern log is rewritten with portable `awk`.
- **CI**: the bash syntax-check loop reported only the last file's status, so a
  syntax error could pass CI; failures now aggregate and fail the job. shellcheck is
  blocking (was `|| true`) and covers `tests/` and `templates/` too.
- **repo-audit / repo-audit-notify**: removed a hardcoded personal repo name and a
  hardcoded `$HOME/bin` install path (the notifier now resolves its sibling script).

### Added

- The repo now follows its own standard: a root `AGENTS.md`, a one-line `CLAUDE.md`
  include, and a real `docs/solutions/` fix log seeded with the bugs fixed above.
- `tests/run-tests.sh`: plain-bash test suite (isolated `HOME`, throwaway git repos)
  covering `pr-risk`, `wt` claim/reuse, the `land-safely` failing-test gate, and the
  SessionStart config check. Runs in CI.
- Issue templates (bug, harness-behavior report) and a PR template asking for the
  real-run evidence CONTRIBUTING already required.
- README: CI badge; the quick-start no longer clobbers an existing `AGENTS.md`.

## [0.1.0] - 2026-07-01

Initial public release.

### Added

- **STANDARD.md**: the seven-part house standard. One source of truth (`AGENTS.md`
  canonical, `CLAUDE.md` as `@AGENTS.md` include), the `docs/solutions/` fix log,
  anti-drift `## Keep in sync` contracts, the self-healing SessionStart hook, commit
  authorship, default-to-main commit flow, and multi-account deploy hygiene.
- **bin/**: reusable, dependency-free bash workflow scripts. `repo-audit`,
  `secrets-audit`, `pr-risk`, `pr-approve`, `land-safely`, `crew`, `wt`,
  `repo-audit-notify`. Scan roots are configurable via `AGENT_STD_ROOTS`.
- **templates/**: a worked `docs/solutions/` fix-log entry with required frontmatter,
  the SessionStart self-healing hook, and a git pre-commit + gitignore starter.
- MIT license, README, CONTRIBUTING, and a code of conduct.
