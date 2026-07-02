---
description: Adopt the agent standard here — run the wizard, then fill AGENTS.md in from the real codebase
---

Adopt the agent standard in the current project, end to end:

1. Run the wizard non-interactively:
   `bash "${CLAUDE_PLUGIN_ROOT}/bin/adopt" --yes`
   It is idempotent and never deletes or overwrites existing content. Show the user
   its scorecard output.

2. If AGENTS.md now contains `TODO:` placeholders, replace **every one** with real
   content derived from THIS codebase — do not leave boilerplate and do not invent
   anything you cannot verify from the files:
   - the one-sentence description of what the project actually is,
   - Architecture: where the important code lives (3–5 bullets),
   - Commands: the build/dev/test commands that actually exist (check package.json,
     Makefile, pyproject.toml, etc. — only list commands that work),
   - Conventions: real house patterns you can observe in the code,
   - Before shipping: the project's actual test/lint gate,
   - Keep in sync: file pairs that genuinely co-vary in this repo (e.g. env vars
     and .env.example, a route list and its docs). If none are evident, keep one
     honest example and note it's a starting point.

3. If the wizard reported that BOTH CLAUDE.md and AGENTS.md exist with their own
   content, merge them yourself: AGENTS.md keeps all content from both, CLAUDE.md
   becomes the single line `@AGENTS.md`. Never lose a line of the user's content.

4. Verify and hand off: run `bash "${CLAUDE_PLUGIN_ROOT}/bin/adopt" --check`, show
   the final scorecard, and summarize in plain language what changed. If the changes
   are uncommitted, offer to commit them.
