# Worked example: orchestrator + workers (Claude Code)

A concrete instance of the model-routing policy ([STANDARD.md §8](../STANDARD.md#8-model-routing-multi-model-setups)):
the strongest model orchestrates, cheaper models execute, and a second vendor
provides an independent perspective. Model names are deliberately generic —
current rankings are *config* (keep yours private and fresh); the shape below is
the policy, and it outlives any given model generation.

| Role | Pinned to | Used for |
|------|-----------|----------|
| orchestrator | your strongest model, max reasoning | plan, decompose, synthesize, judge |
| deep-reasoner | a strong-reasoning model | architecture, hard debugging, algorithm design |
| fast-worker | a cheap fast model | boilerplate, tests, formatting, simple edits |
| peer engineer | a second vendor's agent CLI | whole problems that need a different perspective |

## Setup

1. **Main model = orchestrator.** Set your strongest model as the main model with
   reasoning effort at max (`/model`, then the effort setting).

2. **Create the two role subagents** with `/agents`, each pinned to its model with
   a one-line charter:
   - **deep-reasoner** — "Use for reasoning-heavy phases: architecture, debugging
     complex issues, algorithm design. Think thoroughly, return a concise
     conclusion the orchestrator can act on."
   - **fast-worker** — "Use for mechanical tasks: boilerplate, tests, formatting,
     simple edits. Execute efficiently."

3. **Wire up the second vendor.** Install its agent CLI, then its Claude Code
   plugin (marketplace add → install → run its setup command), so the
   orchestrator can delegate to it — backgrounded for anything long.

4. **Add the routing block to your `AGENTS.md`** (not CLAUDE.md — that's the
   one-line include, per [§1](../STANDARD.md#1-one-source-of-truth)):

   ```markdown
   ## Orchestration workflow
   You are the orchestrator: plan, decompose, synthesize. Keep your own context lean.
   - Reasoning-heavy phases → deep-reasoner
   - Mechanical work → fast-worker
   - Fresh-perspective problems → the second-vendor CLI (backgrounded). Treat it
     as a peer senior engineer, not a reviewer.
   - High-stakes decisions: task deep-reasoner AND the peer on the same problem
     in parallel, without showing either the other's answer; synthesize the best
     of both.
   ```

5. **Prompt the orchestrator like a tech lead:**

   > Goal: <what you want>. Context: <files, constraints>.
   > You're the lead. Delegate reasoning to deep-reasoner, grunt work to
   > fast-worker, fresh-perspective problems to the peer CLI. Show me your plan
   > first, then execute.

## Why this shape works

- The orchestrator's budget and context are the scarcest resources (§8). Spending
  them on execution starves the planning and synthesis only it can do.
- Role charters make delegation automatic instead of per-prompt ceremony.
- Blind parallel consultation on high-stakes calls avoids anchoring — a
  sequential second opinion inherits the first answer's frame.
- The peer-engineer framing gets you a genuinely different approach; a
  reviewer framing only gets you objections to yours.
