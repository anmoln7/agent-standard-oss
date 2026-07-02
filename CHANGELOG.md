# Changelog

All notable changes to agent-standard are documented here. Versions follow
`MAJOR.MINOR.PATCH`.

## [0.4.0] - 2026-07-01

The standard gets a face: a demo, a website, a badge, and a CI action.

### Added

- **GitHub Action** (`action.yml`): the repo doubles as a composite action —
  `uses: anmoln7/agent-standard-oss@v0.4.0` after checkout runs the `adopt --check`
  scorecard and fails the build on drift. This repo's own CI dogfoods it (`uses: ./`).
- **ADOPTERS.md + badge**: a PR-able adopters table and an
  `agent-standard: adopted` shields.io badge; the `adopt` wizard now mentions both
  on a 6/6 finish.
- **Animated demo** (`.github/demo.svg`): a hand-built animated terminal SVG of the
  `adopt` wizard, embedded in the README — no recording tooling, crisp at any size.
- **Website**: STANDARD.md and ADOPTERS.md rendered via pandoc and deployed to
  GitHub Pages at <https://anmoln7.github.io/agent-standard-oss/> on every push to main.
- **crew concurrency cap**: `CREW_MAX_PARALLEL` (default 4, `0` = unlimited) — a
  capped `crew run` launches a batch and leaves the rest queued. Task ids are now
  batch-stamped so a second run can't clobber a running batch's prompt files or
  tmux windows.

### Security

- All workflow `uses:` lines are pinned to commit SHAs (with `# vN` comments)
  instead of mutable tags.

## [0.3.0] - 2026-07-01

Onboarding for humans who don't live in the terminal.

### Added

- **bin/adopt**: a friendly interactive wizard that adopts the standard in any
  project. Plain-English explanations, a before/after scorecard, asks before every
  change, never deletes or overwrites, and offers to commit exactly the files it
  touched. `--check` prints the scorecard and exits nonzero if gaps remain (usable
  as a CI gate in adopting repos); `--yes` runs unattended. Covered by 7 new tests.
- README "New to this? Start here" section pointing at the wizard.

### Fixed

- **secrets-audit `--all`** scanned only the *first* `AGENT_STD_ROOTS` root; it now
  iterates every colon-separated root.
- **repo-audit** crashed on macOS's system `/bin/bash` 3.2 (`set -u` + empty array
  expansion) when a scan found no repos; all `${repos[@]}` expansions are now guarded.

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
