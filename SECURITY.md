# Security Policy

## Reporting a vulnerability

If you find a security issue in this repository (for example, a script that could
leak a secret or run untrusted input), please report it privately using
[GitHub's private vulnerability reporting](https://github.com/anmoln7/agent-standard-oss/security/advisories/new)
rather than opening a public issue.

## Scope

This project is a set of conventions plus small, dependency-free bash scripts. The
security-relevant surface is:

- **`bin/` scripts** run shell commands over your repos. Read a script before you put
  it on your `PATH`. The read-only ones (`repo-audit`, `secrets-audit`, `pr-risk`) do
  not mutate a repo; the others (`land-safely`, `pr-approve`) perform git operations
  and say so.
- **`templates/hooks/` and `templates/git/hooks/pre-commit`** run automatically at
  session start or commit time once installed. The pre-commit hook shells out to
  `gitleaks` if present; review it before installing globally.

## Keeping secrets out

This repository is public **policy**. Never commit real config here: emails, org ids,
API tokens, deploy account maps, or private repo names. CI enforces this with a
gitleaks scan plus a grep guard that fails the build on any personal-config pattern.
Keep your concrete config in a private file or a secrets manager.

## Supported versions

This is a single-branch project. Security fixes land on `main`; there are no
backported release branches.
