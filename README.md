<div align="center"><pre>
   __ _  __ _  ___ _ __ | |_   ___| |_ __ _ _ __   __| | __ _ _ __ __| |
  / _` |/ _` |/ _ \ '_ \| __| / __| __/ _` | '_ \ / _` |/ _` | '__/ _` |
 | (_| | (_| |  __/ | | | |_  \__ \ || (_| | | | | (_| | (_| | | | (_| |
  \__,_|\__, |\___|_| |_|\__| |___/\__\__,_|_| |_|\__,_|\__,_|_|  \__,_|
        |___/
              A house standard for AI-agent instruction files
</pre></div>

<p align="center"><strong>One source of truth · in-repo fix log · anti-drift contracts · self-healing hooks · commit &amp; deploy hygiene</strong></p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/harness-Claude%20Code%20%C2%B7%20Codex%20%C2%B7%20Cursor%20%C2%B7%20Gemini-black.svg" alt="Cross-harness">
  <img src="https://img.shields.io/badge/shell-bash-121011.svg" alt="bash">
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs welcome">
</p>

<p align="center">
  <a href="#the-problem">Problem</a> ·
  <a href="#the-standard">Standard</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="#whats-in-the-box">What's in the box</a> ·
  <a href="CONTRIBUTING.md">Contributing</a>
</p>

---

## The problem

You have an AI agent (Claude Code, Codex, Cursor, Gemini) working across many repos.
Each repo needs an instruction file — but the moment you have two (`CLAUDE.md` +
`AGENTS.md`, or a README that half-documents things), they **drift**. A 142k-line
instruction file that lies about the codebase is worse than none: the agent confidently
follows stale rules, recreates deleted code, and re-learns the same gotcha every session.

`agent-standard` is a small, opinionated set of conventions that keep agent-instruction
files **honest and single-sourced**, plus a few scripts that automate the safe path.

## The standard

Five rules. The full spec is in **[STANDARD.md](STANDARD.md)**.

| # | Rule | Why |
|---|------|-----|
| **1** | **One source of truth** — `AGENTS.md` is canonical; `CLAUDE.md` is a one-line `@AGENTS.md` include (or a symlink). | `AGENTS.md` is the cross-harness convention; never maintain the same content twice. |
| **2** | **`docs/solutions/`** — a committed, frontmatter-tagged fix log. One past bug/gotcha per file. | Shared, queryable memory every agent and human sees. Inline "corrections logs" rot. |
| **3** | **Anti-drift sync contracts** — a `## Keep in sync` block naming the file pairs that must agree. | Prose inventories rot; pin drift-prone pairs in writing (or a test). |
| **4** | **Self-healing SessionStart hook** — only for repos with silently-failing config. | Fixes the common problem (missing dir, loose `.env` perms) before it bites. |
| **5–7** | **Authorship, commit-flow, and deploy hygiene** — sanctioned commit identities, default-to-main, multi-account deploy safety. | Keeps history clean and deploys pointed at the right account. |

## Quick start

Adopt the standard in an existing repo in five steps (full recipe in
[STANDARD.md → Migration recipe](STANDARD.md#migration-recipe-monolithic-claudemd--standard)):

```bash
# 1. Make AGENTS.md canonical, CLAUDE.md a one-line include
git mv CLAUDE.md AGENTS.md 2>/dev/null || mv CLAUDE.md AGENTS.md
printf '@AGENTS.md\n' > CLAUDE.md

# 2. Start a fix log
mkdir -p docs/solutions
cp path/to/agent-standard/templates/docs/solutions/EXAMPLE-*.md docs/solutions/

# 3. (optional) add the self-healing hook for repos with silent-failure config
cp -r path/to/agent-standard/templates/hooks .

# 4. Add a "## Keep in sync" block to AGENTS.md for your drift-prone file pairs
```

Then drop the `bin/` scripts on your `PATH` for the automated safe path
(see [What's in the box](#whats-in-the-box)).

## What's in the box

```
STANDARD.md                        the spec (read this)
bin/                               reusable agent-workflow scripts (bash, no deps)
  repo-audit                       read-only health report across your repos
  secrets-audit                    full-history secret scan of a repo (not just staged)
  pr-risk / pr-approve             classify a change ROUTINE vs NOVEL; gate merges
  land-safely                      first-pass agent code -> clean reviewed PR
  crew / wt                        run parallel agent tasks / manage git worktrees
templates/
  docs/solutions/EXAMPLE-*.md      a worked fix-log entry with the required frontmatter
  hooks/                           the SessionStart self-healing hook
  git/                             a pre-commit hook + gitignore starter
```

Scripts take a config-first stance: e.g. `repo-audit` and `secrets-audit` scan
`AGENT_STD_ROOTS` (colon-separated, defaults to `~/Documents/GitHub:~/Code:~/src`).

## Design principles

- **Cross-harness.** `AGENTS.md` is read by Codex, Cursor, Gemini, and Agent Skills;
  the `@AGENTS.md` include points Claude Code at the same file. No harness lock-in.
- **Single-source or bust.** The only anti-pattern this fights is *duplication*. Two
  complementary files are fine; two files with the same content are not.
- **Config stays private.** The standard is public policy; your concrete account maps,
  emails, and secrets belong in a private file or a secrets manager, never here.

## Contributing

PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Good first contributions: a new
`templates/docs/solutions/` example, a harness this standard hasn't been tested against,
or a `bin/` script that automates another safe path.

## License

[MIT](LICENSE).
