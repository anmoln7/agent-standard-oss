# Changelog

All notable changes to agent-standard are documented here. Versions follow
`MAJOR.MINOR.PATCH`.

## [Unreleased]

### Added

- **§3 covers claims that must be recomputed:** the section handled drift between
  two files and drift in a lone stale fact, but both assume the claim has a
  source you can re-read. A judgment about state — `status: complete`, `done`,
  `shipped` — has no such source, so nothing drifts against it and no rule fired,
  leaving a status from abandoned work asserting itself to every agent that reads
  the file. Where the repo already holds the evidence, the status is now derived
  a second way from its own parts and the disagreement reported. Four rules keep
  it honest: the authored value stays authoritative (warn, never rewrite), the
  finding shows the derivation's inputs including the empty ones, and drift is
  counted rather than gated. Scoped to derivations that are cheap and
  unambiguous — a derived status that is itself a guess is a second unreliable
  claim, not a check on the first.
- **§4 covers context-injecting session hooks:** the section was scoped to
  repairing config that fails silently and said nothing about a `SessionStart`
  hook that injects orienting state, so the obvious implementation — a
  hand-maintained blob injected every session — was the §1 duplication failure
  arriving through a mechanism §1 never mentions. Such a hook must now derive its
  content from repo state rather than carry it, declare what it is *not* (a
  health summary read as a task list, a diagnostics list worked through as a
  startup checklist), and mark cached data stale inline where a reader cannot
  miss it.
- **§9 prefers a derived queue over a hand-maintained one:** the queue already
  had to be readable by any agent, which a committed status field satisfies while
  still being wrong. Where queue state can be derived from the work itself, the
  derivation now wins — it is the only kind that survives a long unattended run.
- **§1 says what a ship gate must answer:** the skeleton's `## Before shipping`
  line asked for "tests, lint, build" and left the two questions an agent
  otherwise answers for itself unaddressed — what counts as done, and in what
  order to check. Done is now defined as runtime evidence quoted from a run of
  this change, never written code or a previous green; and the gate is an ordered
  ladder (static → behavior → system) where a failure at one layer stops the run.
  A clean typecheck is the layer agents over-trust, which is why the ordering is
  written down rather than implied. This repo's own gate now follows it.
- **§1 covers the environment:** a repo can document its build perfectly and
  still be a broken harness if the agent cannot reproduce the toolchain. A
  committed lockfile and a pinned runtime version are now called for, with the
  reason they stay out of the six checks: both are language-specific, and the
  checks are deliberately language-agnostic.
- **`adopt --check` says what to do, not just what is missing:** every failing
  check now prints a concrete remediation line keyed to its STD-* id. The
  scorecard previously named the gap for the next level only, leaving the reader
  to infer the remedy for the rest.
- **`adopt --check` reports a drifted fix log:** §2 requires `module`, `tags`,
  `problem_type`, and `date` on every entry, and nothing checked it — STD-04
  passes on an empty `docs/solutions/` directory, so entries missing the fields
  scored a silent 6/6. The checkup now names how many entries are missing them.
  It is a note, not a score change: the STD-* ids are a public contract, and
  tightening one would move repos that pass today. The shipped `EXAMPLE-*`
  templates are excluded — they are scaffolding, not the repo's own entries.

### Fixed

- **A test's `cd` leaked and voided the next test:** a new remediation test moved
  into an empty scratch directory and never came back, so the EXAMPLE-*
  frontmatter test that followed ran in a folder with no `docs/solutions/` and
  passed because there was nothing to find. Under `set -uo pipefail` without
  `-e` the failed redirect never aborted the run — the suite stayed green while
  an assertion was dead. The block now runs in a subshell.
- **The EXAMPLE-* exclusion test proved nothing:** it copied the shipped
  templates, which carry complete frontmatter and so are never flagged whether
  or not the name-based skip works. It now uses a deliberately thin `EXAMPLE-*`
  entry, which only the skip can keep quiet.
- **`adopt` commits now disclose agent authorship:** the wizard's `adopt the
  agent standard` commit carried no trailer, so a script-written commit was
  indistinguishable from a hand-written one. It now carries `Assisted-by:`, as
  STANDARD.md §5 requires of every agent-authored commit — a human author line
  does not exempt it.
- **`adopt` names the flag you got wrong:** an unknown option printed only the
  usage line, so a typo gave no hint which flag was rejected. It now echoes the
  offending flag and points at `--help`.
- **`adopt --check` says when a folder isn't a git repo:** outside a repo it
  scored `$PWD` and rendered a normal 0/6 card, so a mistyped path read as a
  real result about the repo you meant. The human output now labels it; `--json`
  is unchanged (the check IDs are a public contract).
- **`bin/doc-gate-check` refuses to run against another repo:** it resolved its
  paths from its own location, so running it from a different checkout silently
  reported on *this* repo — a plausible "ok" about a tree the caller wasn't
  looking at. It now exits 2 and says where it actually points. Paths resolve
  with `pwd -P` so the macOS `/var` vs `/private/var` symlink can't defeat the
  comparison.

### Added

- **STANDARD.md §9 — in a shared tree, touch only what you own:** isolation is
  the rule, but agents land in one tree constantly and never by decision (a
  second session, a subagent inheriting `cwd`, the human's own uncommitted
  work). Work additively; never `git stash` (including the `--autostash` that
  rides along with `git pull --rebase`), switch branches, add/remove a
  worktree, or reset. Each silently takes a peer's uncommitted changes, and the
  peer's only symptom is that its work vanished. Unrecognized files are not
  stray — leave them.
- **STANDARD.md §10 — some actions are gated by default, not by policy:** four
  actions earn a gate in every repo because each is cheap, one-line, and looks
  routine in a diff while the cost lands permanently somewhere the diff can't
  show — adding or patching a dependency, publishing or bumping a version,
  writing outside the repo boundary, and committing real data as example data.
  §6's *hard to revert* test, moved off code and onto actions.
- **STANDARD.md §3 — claims that drift alone:** a sync contract catches drift
  *between* files and cannot catch `AGENTS.md` going stale by itself; a build
  command that quietly stopped working breaks no pair, so no rule fires. Name
  the origin for derived facts, pin executable claims to a gate rather than a
  note, and stop hand-keeping what a script can list.
- **`bin/doc-gate-check` — documented commands pinned to the CI gates:** the
  `shellcheck` invocation in `AGENTS.md` and the one in `ci.yml` were
  byte-identical and uncovered by `Keep in sync`, so either could grow a path
  the other never learned about. The script compares each pinned pair and fails
  on drift; a command missing from *either* side fails too, so deleting a gate
  can't pass as "both sides agree". Pin another pair by appending a line to
  `PAIRS`.
- **STANDARD.md §11 — three invocation tiers, cheapest one wins:** referencing a
  skill and saving one in the repo both cost nothing resident; only auto-firing
  buys prompt space (~50–280 tokens per skill, on every message). Put each skill
  in the cheapest tier that meets its activation need and promote deliberately —
  what used to be a single install decision is now two independent ones.
- **STANDARD.md §11 — the auto-fire budget is a budget:** assume well under a
  hundred reliably-firing skills per agent as a working ceiling, because input
  length degrades reasoning before the nominal context limit and each added
  description dilutes the rest. Count them; know what each buys.
- **STANDARD.md §11 — don't bid for attention in the description:** a missed
  match is silent, so the tempting fix is padding the one-liner with shouted
  trigger conditions. It wins for one skill and taxes every message. The honest
  fixes are a sharper trigger, a narrower scope, or demotion behind a router.
- **STANDARD.md §2 — generate the alternatives before the choice:** "alternatives
  rejected" is the one decision-record field satisfiable after the fact, and
  strawman rivals read identical to real deliberation. Each alternative now names
  a condition under which it would have won, and the record is written while the
  design is still open.
- **STANDARD.md §9 — autonomy is bounded by verification, not generation:**
  a loop earns only as much autonomy as a cheap, unfakeable check can green-light;
  faster generation deepens the review pile rather than relieving it.
- **STANDARD.md §9 — comprehension debt:** passing tests aren't understanding;
  keep fully-unread loops confined to cheap, reversible work and require a human to
  hold the design for anything expensive to undo (auth, billing, architecture).

- **STANDARD.md §10 — the capability triangle:** never combine private-data
  access + untrusted input + an outbound path in one agent; break the triangle at
  one side per trust boundary. A named security rule alongside the existing
  least-privilege and prompt-injection guidance.
- **Acceptance Criteria Contract template** (`templates/docs/EXAMPLE-acceptance-criteria.md`):
  the four-field shape (Objective · Constraints · Validation method · Escalation
  protocol) referenced by §10's "success criteria precede work" rule.

- **STANDARD.md §8 — quota and reasoning-effort routing:** route against live
  quota %, not just per-token cost (subscription pools are the binding
  constraint; swapping the default when one runs dry is a one-line config
  change), and dial a capable model's reasoning effort down rather than dropping
  to a weaker model — plus avoid recursive max-effort fan-out modes.
- **`examples/orchestration-workflow.md` — worked quota-routing example:** a
  private `routing.local.yml` shape (role → model → pool, with reset windows and
  a reserved premium pool), the one-line `default_vendor` switch for a drained
  pool, and the `AGENTS.md` rule an agent follows to route against live quota.
- **STANDARD.md §10 — compact errors before feeding them back:** re-inject a
  failed tool call's *message plus the decisive line*, not the raw dump (store
  the full log and link it per §9); cap accumulated raw failures and escalate the
  compacted history up the ladder rather than piling failures into context.

- **Maturity level in `adopt --check` (STANDARD.md §1):** the scorecard now
  reports a level (L0 unharnessed → L3 safe) that gates on the *shape* of the
  harness, not the raw point count. Secret hygiene is a floor for the top level,
  so a repo passing five checks but leaking `.env` reads as L2, not "almost
  perfect." `--check` exit 0 now means "reached the top level."
- **Stable check-ID contract:** each check has a permanent `STD-01`…`STD-06`
  identifier; `--json` gained `id`, `level`, and `level_name` fields (existing
  fields unchanged) so CI can gate on the score without misreading new versions.
- **STANDARD.md §1 — "what the check does not measure":** an explicit ceiling —
  a deterministic scan confirms a file exists and parses, never that its contents
  are true; a high score is necessary, not sufficient.

- **STANDARD.md §2 — three enforcement mechanisms for "compile, don't retrieve":**
  a **review-marker commit gate** (a `PreToolUse` hook blocks `git commit` until
  a session-scoped review marker exists, with diff-scoped strictness and a
  documented bypass), a **debt ratchet** (gate on a metric *not increasing* past
  a committed baseline instead of an absolute line the repo can't meet today),
  and a **pre-change decision record** (a bounded ADR with an explicit skip-list,
  the forward-looking twin of the fix log).
- **`templates/hooks/scripts/review-gate.sh`** and
  **`templates/hooks/scripts/ratchet.sh`:** copy-in bash implementations of the
  two mechanical gates above, each with editable per-repo config and tests.
- **`VERSION` + `bin/sync-version`:** the release version now lives in one
  `VERSION` file; `sync-version` derives it into `.claude-plugin/plugin.json`,
  `.claude-plugin/marketplace.json`, and the README CI-example pin. `sync-version
  --check` gates drift in CI and the test suite, replacing the old three-way
  equality assertion — the derived files can no longer be hand-edited out of sync.

### Changed

- **`bin/crew`:** tmux-mode runs now tee agent output to
  `~/.config/agent-standard/crew/task-*.log` as well as the pane. Previously a
  task's output lived only in a tmux scrollback that dies with the session, so
  the record of *why* a task failed was unrecoverable minutes later. The
  non-tmux path already logged; this makes both modes consistent.
- **`.gitattributes`:** replaced the per-glob `eol=lf` patterns with a blanket
  `* text=auto eol=lf`, so a new script under any path is normalized to LF
  without adding a pattern.

## [0.10.0] - 2026-07-02

Two repo-hygiene practices: continuous agent-authorship disclosure and a second
worked fix-log example.

### Added

- **STANDARD.md §5 — Agent-authorship disclosure:** disclosure is continuous,
  not a one-time PR note. Every agent-authored commit carries an
  `Assisted-by:`/`Co-Authored-By:` trailer naming the agent and whether it
  acted autonomously or under supervision — a human git identity on the
  commit does not exempt it. Agents disclose their own identity in PR/issue
  comments and restate it each review round. No fake-review theater: an
  inhumanly fast "reviewed and tested by me" turnaround is itself a signal of
  automation, not something to paper over.
- **templates/docs/solutions/EXAMPLE-stale-editable-install.md:** a second
  worked fix-log example — the sneaky Python environment-contamination
  pattern where a stale editable install in another checkout makes `pytest`
  resolve a brand-new module to a different worktree's stale namespace
  package, even though `python -c "import ..."` works fine. Copied into new
  repos alongside the existing SEO example, so `docs/solutions/` starts
  seeded with two genuinely different problem shapes.

## [0.9.0] - 2026-07-02

A new section for a problem the standard hadn't addressed: knowledge that
lives in one person's head, not in any file.

### Added

- **STANDARD.md §11 — Knowledge succession (skill libraries):** when a repo's
  tacit knowledge (debugging instincts, settled arguments, unwritten
  discipline) needs to survive a person or run on a cheaper model, generalize
  it into a skill library instead of leaving it tacit. Discover before you
  write (read the repo like an incoming engineer, ask only what it can't tell
  you); one skill per topic with no duplicate homes for a fact; ground-truth
  only — every command/flag/path verified before it's written, unproven items
  stay labeled; provenance and re-verification commands for anything that can
  drift; write-scope discipline (author only inside the skills directory);
  separate authoring from an independent review pass. Flagged as expensive —
  reserved for genuinely at-risk knowledge, not the default way to document a
  repo.

## [0.8.0] - 2026-07-01

The spec's core sections get their biggest upgrade: a model for what good
context *contains*, a taxonomy for how agents fail, and concrete safety
policy for autonomous loops.

### Added

- **STANDARD.md §1 — the four S's of context:** instruction-file content comes
  in four layers — Syntax (your conventions), Service (how this repo works and
  is deployed), System (what the org already runs; integrate-by-default), and
  Strategy (the tie-breaking business context). Each builds on the one below;
  skipping layers produces slop regardless of model quality.
- **STANDARD.md §2 — the slop list:** recurring agent slop is logged in the fix
  log like incidents, one category per file. Six named categories: plausible-
  but-wrong, over-engineered, convention-blind, hallucinated APIs, defensive
  slop, cargo-cult patterns. Capture a category once; it becomes context that
  prevents it forever.
- **STANDARD.md §10 — the five-question stop policy:** a turn cap is an
  organizational judgment wearing a numeric disguise. Every autonomous loop
  answers in writing: what may it touch (blast-radius fence), how long may it
  run, what counts as proof, what must it record, when does a human get pulled
  in.
- **STANDARD.md §10 — retry-storm discipline:** retries move pressure, they
  don't remove failure — exponential backoff + jitter under a written budget,
  one layer owns retries per dependency, idempotency keys for any retried
  write, circuit breakers past the budget, fallbacks designed deliberately.
- **STANDARD.md §10 — sharper gates:** review output against the contract
  ("did it satisfy it, and did it add anything beyond it?") instead of
  line-by-line diff reading; and scrutiny scales with novelty — easy is a
  smell, and an agent that visibly struggles marks exactly where verification
  must be hardest.

## [0.7.0] - 2026-07-01

One new spec section plus §9 hardening, distilled from the agentic-patterns
canon and field notes on loop engineering — only the parts the standard didn't
already cover, reduced to enforceable policy.

### Added

- **STANDARD.md §10 — Guardrails and recovery:** failures walk a planned ladder
  (detect → retry → fallback → degrade → escalate), never silence; guard in
  independent layers (input, output, scope); least-privilege tool allowlists per
  dispatch; external content is data, not instructions (prompt-injection
  discipline); escalation criteria are written into AGENTS.md, not vibed —
  §9's continue-don't-confirm is only safe with explicit stop conditions;
  success criteria are defined as a verifiable contract *before* work starts,
  the author is never the sole judge of its own work, and self-reported
  completion is a claim, not a result.
- **STANDARD.md §9 additions:** isolation under parallelism (one worktree + one
  branch per concurrent agent; concurrency capped by *operator review
  bandwidth*, not machine capacity); unattended loops need breakers (runtime
  limit, consecutive-failure threshold, deterministic stop conditions — loops
  drift quietly rather than exploding); verifiers decay and must be audited
  (verification debt: quality slides while outputs still compile).

## [0.6.0] - 2026-07-01

Two new spec sections distilled from field-tested multi-model workflows —
de-personalized to policy, per the house rule (rankings and vendor picks are
config; the routing rules are the standard).

### Added

- **STANDARD.md §8 — Model routing (multi-model setups):** keep a private
  cost/intelligence/taste ranking table; defaults-not-limits with standing
  permission to escalate on quality ("judge the output, not the price tag");
  intelligence > taste > cost for anything that ships; route bulk work cheap,
  user-facing work to taste, reviews to the strongest models across vendors;
  cross-vendor access via thin CLI wrapper agents; the orchestrator is the
  scarcest resource (plan/decompose/synthesize only — protect its provider more
  conservatively than workers'); treat a strong second vendor as a peer, not a
  rubber stamp; high-stakes decisions get blind parallel consultation, then
  synthesis.
- **STANDARD.md §9 — Delegation and long-running work:** files over context
  (workers return a TL;DR + path, never a long inline report); verification-first
  goal loops that return converged results, not drafts; reviews gate — absence is
  inconclusive, verdicts are saved durably, reviewer misses become regression
  tests, and one caught bug class triggers a codebase-wide sweep; continue-don't-
  confirm; quiet-is-not-dead liveness (reconcile multiple signals, resume from
  state files); explicit-pathspec commits under parallel workers; blocked workers
  escalate rather than bypass.
- **examples/orchestration-workflow.md:** a worked Claude Code setup for §8 —
  orchestrator at max reasoning, pinned deep-reasoner and fast-worker subagents
  with one-line charters, a second-vendor peer CLI, the AGENTS.md routing block,
  and the tech-lead prompt shape.

## [0.5.0] - 2026-07-01

Install in one line; or let Claude Code do the whole thing.

### Added

- **`install.sh`**: `curl -fsSL .../install.sh | bash` installs to
  `~/.agent-standard`, puts the scripts on PATH (symlinks into `~/.local/bin` when
  it's already on PATH, else one profile line), is idempotent, needs no sudo, and
  touches nothing outside `$HOME`.
- **Claude Code plugin** (`.claude-plugin/` + `commands/`): add the repo as a
  marketplace and install the `agent-standard` plugin, then
  `/agent-standard:adopt` runs the wizard **and** fills in the AGENTS.md TODOs from
  the real codebase (verified commands only, no invented content);
  `/agent-standard:check` shows the read-only scorecard with plain-language
  explanations.
- Installer and plugin-metadata tests (19 total); `install.sh` covered by the CI
  syntax and shellcheck gates.

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
