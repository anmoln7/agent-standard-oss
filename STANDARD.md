# Agent-Instruction House Standard

How to structure agent-instruction files across a set of repos: one source of
truth, an in-repo fix log, written anti-drift rules, and a self-healing session
hook.

Apply this to any repo an AI agent (Claude Code, Codex, Cursor, Gemini) works in.

---

## 1. One source of truth

A repo has **one** canonical instruction file: `AGENTS.md`. It holds everything an
agent (or human) needs to work on the repo: architecture pointer, build/test
commands, conventions, gotchas, ship rules.

`CLAUDE.md` is **one line**, an include:

```
@AGENTS.md
```

Why: `AGENTS.md` is the cross-harness convention (Codex, Cursor, Gemini, Agent
Skills all read it). Claude Code reads `CLAUDE.md`, so the include points it at the
same canonical file. **Never maintain the same content in two files**. That is the
failure mode this prevents (a large monolithic instruction file drifted because there was no
single source).

### Accepted alternative: a symlink

A `CLAUDE.md` **symlink → `AGENTS.md`** is equally compliant and in some ways
stronger: any tool that opens `CLAUDE.md` gets the full canonical content with zero
drift, no `@import` support required (a `CLAUDE.md -> AGENTS.md` symlink, git mode `120000`).
Leave such repos as-is.

Tradeoff: symlinks don't survive some Windows checkouts / zip exports, where the
`@AGENTS.md` text include is more portable. Pick per repo; both satisfy
one-source-of-truth. Do **not** convert a working symlink to an include just for
uniformity; it is a lateral move.

If a repo genuinely needs Claude-only nuance, put the `@AGENTS.md` line first, then
the small Claude-specific addendum below it. This should be rare.

### Accepted exception: a deliberate two-file split

A repo may keep `CLAUDE.md` and `AGENTS.md` as **complementary** files (not
duplicates) when the content genuinely divides by audience, e.g. `AGENTS.md` = install +
operating protocol + routing (cross-harness onboarding), `CLAUDE.md` = architecture
reference / key files / test layout. This is compliant
**as long as the two never hold the same content** and a `## Keep in sync` rule
covers any overlap. The anti-pattern is *duplication*, not *two files*.

### AGENTS.md skeleton

```markdown
# <Repo>: Agent Guide

One-sentence description of what this repo is.

## Architecture
Where the code lives, the 3 to 5 things you must understand before editing.

## Commands
Build / dev / test commands. The ones you actually run.

## Conventions
House style, naming, patterns to follow, orphaned code NOT to recreate.

## Gotchas
The traps. (See docs/solutions/ for the full fix log.)

## Before shipping
Tests, lint, build, whatever the ship gate is.

## Keep in sync
<see section 3>
```

Keep AGENTS.md scannable. Anything that is a *specific past incident* goes in
`docs/solutions/`, not inline. That keeps AGENTS.md from growing without bound.

---

## 2. `docs/solutions/`: the fix log

A committed, queryable record of past bugs, fixes, and hard-won patterns. The
in-repo, shared version of per-machine agent memory: every agent and human that
opens the repo sees it.

**One fix per file.** Filename: `docs/solutions/<area>-<short-slug>.md`.

Required frontmatter:

```markdown
---
module: <which part of the codebase, e.g. "booking", "auth", "build">
tags: [<keywords for search>]
problem_type: bug | gotcha | pattern | workflow
date: YYYY-MM-DD
---

## Problem
What went wrong / what's confusing.

## Cause
Why it happens (the root cause, not the symptom).

## Fix
What to do. Concrete, copy-pasteable where possible.
```

When a repo already grows an inline "Corrections Log" or "Things Claude Has
Learned" section, **migrate those entries into
`docs/solutions/` one file each** and leave a one-line pointer in AGENTS.md.

---

## 3. Anti-drift sync contracts

When two files must agree, say so in writing. Drop a `## Keep in sync` block into
AGENTS.md:

```markdown
## Keep in sync
- Add an env var → document it in `CONFIGURATION.md` (or `.env.example`).
- Add a CLI flag / route → update the relevant section here and the README example.
- Change <file A> → update <file B> (and the test that pins them, if any).
```

List only the pairs that actually drift in this repo. The rule exists because
prose inventories rot: a hand-kept "Inventory (legacy)" file-list drifts from the
codebase until it is removed. Prefer "read the directory" over a hand-kept
list; where a list is unavoidable, pin it with a sync rule or a test.

---

## 4. Self-healing SessionStart hook

Only for repos with config that **fails silently** (an `.env` with secrets, a
required output dir). A `SessionStart` hook fixes the common problems before they
bite instead of after.

`hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/hooks/scripts/check-config.sh\""
          }
        ]
      }
    ]
  }
}
```

The script (template in `templates/hooks/scripts/check-config.sh`) does two
generically-useful things, both cross-platform-guarded:

- **Ensure required dirs exist** (`mkdir -p` the output/cache dir).
- **Auto-`chmod 600` a loose-permission `.env`** and warn, so a world-readable
  secrets file gets locked down at session start.

Adapt the env-file path and dir per repo. Skip the hook entirely where there's no
silent-failure config to heal. Do not add ceremony for its own sake.

---

## 5. Commit authorship

Commits in any repo under this standard must be authored by one of a **small,
explicit set of sanctioned identities**. No stray author (a work email, a machine
default, a bot) should ever land in history. Pick your allowed identities and list
them, e.g.:

- `you <you@example.com>`
- `you-alt <you-alt@example.com>`

Before committing, verify the local identity resolves to one of them:

```bash
git config user.name && git config user.email
```

If it doesn't, set it per-repo (`git config user.email you@example.com`). Do **not**
commit under a different identity and fix it later. An agent committing on your behalf
uses whichever sanctioned identity the repo is already configured for; if unset, fall
back to a documented default.

Co-author trailers (`Co-Authored-By:`) for the agent are fine and don't count as the
commit author.

> **Multi-account hosting.** If your repos live under more than one GitHub (or GitLab)
> account, remember the hosting account is separate from commit identity, and CLIs like
> `gh` keep only one account *active* at a time. Working in a repo owned by a non-default
> account without switching first (`gh auth switch --user <account>`) makes reads/pushes
> hit the wrong account, which returns a bare `404 / repository not found`, a silent
> "wrong active account," not a missing repo. Note the required account at the top of that
> repo's `AGENTS.md` and switch before any `gh`/push operation.

---

## 6. Commit + push flow: default to the main branch

**Default: commit straight to the default branch (`main`/`master`) and push it.** For
solo / small-team repos, a feature branch + PR for routine work just adds ceremony and
leaves stale branches behind (see the anti-pattern below). Complete the loop: commit and
`git push origin <default>`, so the work is actually on the remote, not parked on a local
branch waiting for a second ask.

**Branch + PR only when the change is risky.** Open a branch instead of committing to main
when the change is any of:

- a **schema/data migration** or anything that can corrupt or lose data,
- a **large or wide-reaching refactor** touching many files or core modules,
- **hard to revert** (irreversible, or a one-way door), or
- likely to **break the build / leave main undeployable** if it lands half-done.

For those, branch off the default, push the branch, and open a PR so main stays green.
Everything else goes straight to main. The user can always override in either direction
("just commit it", "put it on a branch"); when they do, that wins for that change.

### Anti-pattern: branch-per-trivial-change

Do **not** create a `feature`/`add-x` branch for a routine, low-risk edit (docs, a
diagram, a copy tweak, a one-line fix) and then merge it yourself moments later. The
branch adds no review value on a solo repo, and if it's fast-forwarded or rebased into
main the leftover branch lingers on the remote showing a misleading "Compare & pull
request" banner. Commit low-risk work directly to main; reserve branches for the risky
cases above. If a redundant branch does get created, delete it (remote + local) once its
content is on main.

---

## 7. Deploy-account hygiene (multi-account setups)

If you deploy across **more than one account** on a host (Vercel, Netlify, Fly, Cloudflare,
etc.), the CLI usually keeps **one** account logged in at a time, and the account that owns
a deployment is **independent of the git remote owner**. Deploying under the wrong account
fails ("Could not retrieve Project Settings") or, worse, deploys to the wrong project.

Rules for any agent about to deploy:

1. **Never run a bare deploy command.** Run an account-check first that compares the current
   CLI login against the account this repo requires, and only then deploy. A tiny
   `deploy-check` wrapper that reads the required account from the repo's `AGENTS.md` and
   diffs it against the active login pays for itself.
2. **Never infer the account from the git remote.** Read the `> **Deploy:**` line in
   `AGENTS.md`, or cross-check the linked project's org id against a maintained
   account→repo map.
3. **The deploy link is not always at the repo root.** Some projects link the deploy config
   from a subdirectory. If the root has none, find the real one
   (`find . -path '*/.vercel/project.json'`, adjust per host) and run deploy commands **from
   that directory**, otherwise the CLI silently uses whatever account is logged in.
4. **Prefer stored tokens over interactive login.** A per-account token (e.g. from the OS
   keychain / a secrets manager) lets deploys run headless with `--token` and avoids
   flipping the global CLI session to the wrong account. The fix for a wrong-account error
   is the *correct account's token*, not a bare `login` that mutates global state.

If the account-check reports a mismatch, stop and switch accounts. Do not guess your way
through auth.

> Keep the concrete account↔repo map (emails, org ids, domains) in a **private** file or a
> secrets manager, not in this public standard. This section is the *policy*; your account
> list is *config*.

---
## Migration recipe (monolithic CLAUDE.md → standard)

1. **Back up** the current `CLAUDE.md` (scratchpad copy; `git init` + commit first
   if the repo isn't under git).
2. **Rename/move** the content into `AGENTS.md` (if AGENTS.md exists as a stub,
   merge into it; if it's a duplicate, the content is already there).
3. **Replace** `CLAUDE.md` with the single line `@AGENTS.md`.
4. **Extract** any inline "corrections / lessons / gotchas log" into
   `docs/solutions/*.md` with frontmatter; leave a pointer in AGENTS.md.
5. **Add** a `## Keep in sync` block for this repo's drift-prone file pairs.
6. **Add** the SessionStart hook only if the repo has silent-failure config.
7. **Verify:** `head -2 CLAUDE.md` shows the include; diff AGENTS.md against the
   backup to confirm zero content loss (relocation only); `git diff` is reviewable.
