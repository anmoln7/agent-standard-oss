---
description: Score this repo against the agent standard (read-only)
---

Run `bash "${CLAUDE_PLUGIN_ROOT}/bin/adopt" --check` and show the user the scorecard.

Lead with the **maturity level** (L0–L3), not the raw point count: the level gates
on the shape of the harness, so a repo can pass five checks yet sit a level lower
because it's missing the secret-hygiene floor. For each missing item (⬜), add one
plain-language sentence on what it is and why it matters. Change nothing — this is
read-only. If anything is missing, offer to fix it all with /agent-standard:adopt.
