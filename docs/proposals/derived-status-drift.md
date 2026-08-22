---
status: applied
target: STANDARD.md §3 (Anti-drift sync contracts), §4 (SessionStart hook), §9 (Delegation)
date: 2026-08-22
tags: [drift, verification, derived-state, session-context]
see_also: audit-the-default.md, bidirectional-model-routing.md
---

# Derive the status, don't just read it

**Status: applied.** §3 gained "The third kind: claims that must be recomputed",
§4 gained "The other job: injecting orienting context", and §9's queue bullet
gained a clause on derived queue state. This file is the reasoning behind those
changes, kept separately because the argument is longer than the rules.

## The gap this closed

§3 handled two kinds of drift:

1. **Pairwise drift** — two files that must agree, pinned by a `## Keep in sync`
   rule and, at its strongest, by a CI check.
2. **Solo drift** — a claim in `AGENTS.md` that goes stale alone, addressed by
   *"name the origin for derived facts"* and *"prefer a check over a promise"*.

Both are about **facts**: a command, a version, a path. Both assume the fix is to
point at an authoritative source and re-read it.

Neither reached the case where the stale thing is a **judgment about state** —
`status: complete`, `done`, `shipped`, `active`. A status field has no external
source to `grep`. It is a human assertion, and §3's tools did not touch it: no
pair drifts when someone marks a spec complete while its tickets are open, so no
rule fires. The claim sits in the repo asserting itself with full authority, and —
because §1 makes these files the ones every agent reads on every task — an agent
picks it up and plans around it.

The gap in one line: **§3 knew how to re-read a fact. It had no answer for a
claim that has to be re-computed.**

## Why the four properties are separable

The §3 subsection lists four rules. They are independent, and dropping any one
breaks the check in a different way — worth recording, since a partial adoption
is the likely failure:

- **Compute the status from its own parts.** This is the mechanism, and it is
  the piece that makes the check reachable at all: the derivation needs no
  external source of truth, only the artifact's own contents. Without it there
  is nothing to compare and the other three rules have no subject.
- **The authored value stays authoritative.** Without this the check becomes a
  writer, and a writer that overrules human judgment gets disabled the first
  time it is wrong — taking the other three rules with it. Warning-not-error is
  what keeps the check alive long enough to be useful.
- **Show the derivation's inputs.** Without this a finding is unfalsifiable in
  practice: the reader must re-derive the status by hand to decide whether the
  tool or the human is right, which costs more than the check saves. The
  explicit `[none]` matters more than it looks — it separates "checked, found
  nothing" from "did not check", and those have opposite implications.
- **Count it, don't gate on it.** Without this the check is a wall, and walls
  built on a heuristic derivation get routed around. A trending number tolerates
  the derivation being occasionally wrong; a gate does not.

The scope limit in the closing paragraph is load-bearing: a derived status that
is itself a guess is a second unreliable claim, not a check on the first. §9's
rule that an uncalibrated checker is worse than none is the same principle, and
it binds here for the same reason.

## Why §4 needed widening

§4 was scoped to *repair* — `mkdir -p` a required dir, `chmod 600` a loose
`.env`. A `SessionStart` hook that instead *injects orienting context* is a
different job with a different risk profile, and the section said nothing about
it. Left unwritten, the obvious implementation is a hand-maintained prose blob
injected on every session, which is precisely the second-source-of-truth failure
§1 exists to prevent — reintroduced through a mechanism §1 never mentions.

The three disciplines each pre-empt a specific, observed failure mode:

- Hand-written injected context drifts, exactly as any other duplicated content
  does. Deriving it from repo state at session start is the only version that
  cannot.
- Context that does not declare its own scope gets over-read. A health snapshot
  silently becomes a task list; a list of available diagnostics silently becomes
  a startup checklist that a dutiful agent works through before touching the
  actual task. The negation has to be explicit and adjacent.
- Cached data presented without its age reads as current. This is worse than
  omitting it, because the agent now holds a confident wrong belief rather than
  a known gap — and will not re-derive what it thinks it already knows.

## Why §9 needed only a clause

§9 already required the queue to be readable by any agent — a committed
`TODOS.md` or a CLI-reachable tracker. What it did not say is which *kind* of
queue entry survives contact with a long run. A hand-maintained `status` field in
a committed queue file is readable by any agent and still wrong, which satisfies
the letter of the existing rule while failing its purpose. The added clause
points at §3's new subsection rather than restating it.

## Deliberately not adopted

- **No prescribed artifact taxonomy.** Numbered directory trees, typed filename
  prefixes, and a fixed frontmatter schema are one possible encoding of these
  rules, not the rules themselves. The standard prescribes *properties* — one
  source of truth, dense first lines, sync contracts — and §1 already covers doc
  discovery. Mandating a file layout would be the unrequested flexibility the
  standard warns against elsewhere.
- **No separate project-management repo.** Where context lives is covered by
  §1's scoped-instruction-files rule. Splitting it into a second repo is an org
  decision, not a standard.
- **No new `STD-0x` check.** Same reasoning as `audit-the-default.md`: a
  deterministic scan can confirm a status field exists and parses, never that its
  derivation is sound. Whether a repo *has* a cheaply derivable status is a
  judgment call, and a check here would be the false green §1's scoring section
  warns about.
- **No claim that context outweighs code.** It is a defensible provocation, but
  it is an assertion about value, not a rule an agent can follow. §9 already
  carries the operative half — files are the state, context is scarce.

## Worked example already in this repo

`bin/doc-gate-check` is this repo's existing instance of the general pattern: it
recomputes a fact (the resolved file set a documented command covers) rather than
trusting the prose, and fails when the documented and enforced versions diverge.
It predates this proposal and is cited in §3's pairwise-drift bullet. The new
subsection generalizes the same move from *commands* to *judgments about state*.
