# Contributing to agent-standard

Thanks for helping keep AI-agent instruction files honest. This is a small,
opinionated project — contributions that sharpen the standard or automate a safe
path are very welcome.

## Where does my contribution go?

| You want to... | Put it in... |
|----------------|--------------|
| Refine or extend a rule | `STANDARD.md` |
| Add a worked fix-log example | `templates/docs/solutions/EXAMPLE-*.md` |
| Add/improve a workflow script | `bin/` |
| Add a hook or config starter | `templates/` |
| Report that a harness behaves differently | an issue, or a `STANDARD.md` note |

## Guiding principles

The standard earns its keep by being **small and enforceable**. Before adding a rule,
ask:

- **Does it fight real drift?** The whole point is preventing instruction files from
  lying about the codebase. A rule that doesn't reduce drift is ceremony.
- **Is it single-source-friendly?** Never introduce a convention that requires the same
  content in two places without a `## Keep in sync` contract.
- **Does it stay config-free?** The public standard is *policy*. Anything with a real
  email, org id, token, domain, or private repo name is *config* and does not belong
  here.

## Scripts (`bin/`)

- **bash, no runtime deps.** Assume macOS/Linux `bash`; keep it POSIX-ish where easy.
- **Config over hardcoding.** Read paths/roots from an env var with a sensible default
  (see `AGENT_STD_ROOTS` in `repo-audit`). Never hardcode a personal path.
- **Read-only by default.** Audit/report scripts must not mutate a repo. Anything that
  writes (commits, pushes, deletes) states so loudly and is opt-in.
- `bash -n script` must pass. A `shellcheck` clean bill is appreciated.

## PR workflow

1. Fork, branch, make the change.
2. For a script change, include the before/after of a real run in the PR description —
   show it actually does what it claims.
3. Keep PRs focused: one rule or one script per PR.
4. No secrets, no personal config, ever — CI (and reviewers) will reject a PR that
   introduces an email/token/org id.

## Coding standards

- Match the surrounding style; don't reformat unrelated lines.
- Prose in `STANDARD.md`: short sentences, concrete nouns, active voice. Say what the
  rule prevents.

By contributing you agree your work is licensed under the repository's [MIT License](LICENSE).
