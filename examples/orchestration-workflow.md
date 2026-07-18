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

## Quota-aware routing

The table above pins *roles to model tiers*; this section is the *config that
resolves a tier to an actual model today* — and swaps it when a subscription pool
runs dry. Keep this file **private** (a real one names your plans and reset
times); the shape below is the followable part.

A minimal routing config — one row per role, resolving to a model plus the
subscription pool it draws from:

```yaml
# routing.local.yml — PRIVATE. Not committed. Edited, not coded.
default_vendor: A            # the one-line switch: flip this when a pool runs dry

roles:
  orchestrator: { vendor: A, model: A-strong, effort: max }
  deep-reasoner: { vendor: A, model: A-strong, effort: high }
  fast-worker:   { vendor: B, model: B-cheap,  effort: low }
  peer:          { vendor: C, model: C-strong, effort: high }

# One pool per vendor subscription. reset_window = how the plan refills.
pools:
  A: { plan: "max",  reset_window: "5h rolling",  reserve_for: high-taste }
  B: { plan: "team", reset_window: "monthly",     reserve_for: null }
  C: { plan: "pro",  reset_window: "weekly",      reserve_for: null }
```

Then route against **live quota %, not the price list**:

1. **Read quota before dispatching, not after a failure.** A `quota` CLI (or the
   vendor's usage endpoint) reports remaining % per pool. Check it at session
   start and before any large fan-out — an empty pool mid-task strands the work.
2. **Reserve the premium pool.** Pool `A` above is fenced (`reserve_for:
   high-taste`): the orchestrator routes routine work to `B`/`C` and spends `A`
   only on the high-taste phases nothing else does as well, so a bulk job can't
   drain the pool you need for design work.
3. **Pace against the reset window.** Be aggressive on a pool with a generous or
   short-cycle reset (`A`'s 5h rolling); ration one that refills slowly (`C`'s
   weekly). The reset window, not the raw balance, sets how freely to spend.
4. **The switch is one line.** When `A` hits ~0%, flip `default_vendor: A` → `B`
   and every role that resolved to `A` falls back — no code edit, no re-pin. Flip
   it back after the reset. This is the payoff of keeping routing as config
   ([§8](../STANDARD.md#8-model-routing-multi-model-setups)): a dry pool is an
   edit, not an outage.

Put the rule an agent follows into `AGENTS.md` alongside the orchestration block:

```markdown
## Quota routing
Before a large delegation, read remaining quota per pool. Route routine work to
the cheapest non-reserved pool; spend the reserved pool only on high-taste phases.
If a pool is under ~10%, treat it as unavailable and use the fallback vendor —
don't retry into an empty pool. Reserve/reset details live in routing.local.yml.
```

## Why this shape works

- The orchestrator's budget and context are the scarcest resources (§8). Spending
  them on execution starves the planning and synthesis only it can do.
- Role charters make delegation automatic instead of per-prompt ceremony.
- Blind parallel consultation on high-stakes calls avoids anchoring — a
  sequential second opinion inherits the first answer's frame.
- The peer-engineer framing gets you a genuinely different approach; a
  reviewer framing only gets you objections to yours.
- Routing against live quota keeps a cheap-per-token model from stalling the
  session when its pool is dry — and keeping the routing as config makes the
  fix a one-line edit, not a code change under pressure.
