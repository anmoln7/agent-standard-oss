---
module: build
tags: [python, venv, editable-install, pytest, environment]
problem_type: gotcha
date: 2026-07-02
---

## Problem
A brand-new module imports fine under `python -c "import mypkg.newthing"` but
`pytest` raises `ModuleNotFoundError` for that same module, even though the
test file's import looks correct and the module clearly exists on disk.

## Cause
Another checkout of this repo (or an older worktree) has an editable (`-e`)
install registered in a shared or global Python environment. A bare `uv run
pytest` / `pytest` can resolve the package name to *that other worktree's*
`.pth` file instead of this one. The failure is sneaky because import still
partially succeeds — the package resolves as a stale namespace package, so
only newly-added submodules go missing, while everything that existed at the
time of the other install keeps working.

## Fix
Always run tests through this checkout's own virtualenv, not an ambient
interpreter: `uv sync --extra test` (or `pip install -e ".[test]"`) inside the
repo, then `.venv/bin/python -m pytest` — not a bare `uv run pytest` or
`pytest` from `PATH`. If a brand-new module imports under `python -c` but not
under `pytest`, suspect environment contamination (a stale editable install
elsewhere) before suspecting the code.

<!-- This is a template example. Delete it when seeding a real repo's docs/solutions/. -->
