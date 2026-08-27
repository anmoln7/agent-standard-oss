---
status: applied
target: STANDARD.md §8 (Model routing)
date: 2026-08-08
tags: [model-routing, cost, orchestration, schema-adherence]
see_also: audit-the-default.md
---

# Escalation runs both ways

**Status: applied to §8 as the "Escalation runs both ways" bullet.** This file is
the reasoning behind it, kept separately because the argument is longer than the
rule.

## What §8 said before

§8's first bullet grants standing permission to escalate: *"if a cheaper model's
output doesn't meet the bar, rerun the work with a smarter model without asking.
Judge the output, not the price tag."* The tie-break order backs it up —
intelligence > taste > cost.

That is a one-directional ratchet. Every rule pointed the same way: when in
doubt, go bigger. The only counterweight was *"Dial reasoning effort, don't drop
to a weaker model"*, which pushes the *same* direction — stay on the capable
model, just turn its effort down.

Nothing in the section described when a smaller model is the *better* choice on
quality grounds rather than the cheaper choice on budget grounds. "Route by task"
comes closest, but it routes on the task's character (bulk vs. user-facing), not
on the character of individual steps inside one task.

## The argument

Two independent effects, both specific to loops rather than single calls.

**1. Schema adherence is not the same axis as reasoning depth.** A large share of
the calls in an agentic loop are schema-bound: choose a tool, fill its arguments,
extract a typed field, update workflow state. Success on those is "did it emit
exactly the contract" — a compliance property, not a reasoning one. A model
optimized to reason will sometimes elaborate where the contract wanted a
terminal, literal answer, including inventing plausible-looking parameters that
the schema never declared. Depth is not the binding constraint on these steps, so
buying more of it does not buy accuracy, and may cost some.

**2. Per-call overhead compounds multiplicatively.** In a single call, a verbose
model costs you one padded response. In a loop that runs a step dozens or
hundreds of times per user request, the same padding is multiplied by the step
count, and it lands in two budgets at once: spend, and the context window that
every later step has to read. Reasoning tokens have the same shape — thinking
budget spent deciding *which* tool to call is pure loss when the tool was already
determined by the plan. §8 already names the multiplier as what empties a budget
("avoid max fan-out modes"); this is the same multiplier applied to per-call
verbosity rather than to fan-out.

Together these say the frontier model can be simultaneously more expensive *and*
less accurate on exactly the steps that recur most.

## What the rule does and does not claim

**Claims:** route by the character of the step, not the importance of the task
surrounding it. Keep the strong model where an error propagates — initial
decomposition, final synthesis, anything whose output every later step consumes.
Let the mechanical middle run small.

**Does not claim** that small models are generally competitive, that cost should
outrank intelligence, or that the standing permission to escalate is revoked. The
bullet closes with the explicit reconciliation: where routing is genuinely
unclear, the tie-break order still applies. This narrows *where* the question gets
asked; it does not reverse the answer.

**Compatible with the neighbouring bullet.** "Dial reasoning effort, don't drop to
a weaker model" is about a step that genuinely needs reasoning and where the only
question is how much. This bullet is about steps that don't need reasoning at all.
Different populations of step, no conflict — but they sit adjacent deliberately,
because the reader needs both to route correctly.

## Confidence and how to check it

The mechanism is stated as reasoning, not as a measured result, and it should be
read that way. It is consistent with published work on agentic routing and with
the general observation that verbosity compounds in multi-step execution, but this
repo has not run its own benchmark.

That is a deliberate scoping choice: the argument is checkable by anyone who reads
it, so it needs no borrowed number to stand up. If someone wants to harden it:

1. Take one real recursive workflow with a stable success criterion.
2. Run it top-model-everywhere, then again with the schema-bound steps routed to
   the small model, holding prompts, tools, and harness identical.
3. Record success rate, total tokens, and tokens *per LLM call* — the per-call
   figure is where the verbosity effect shows up most directly.
4. If the accuracy delta is negative, weaken the bullet to a cost-only claim; the
   cost half of the argument survives independently of the accuracy half.

The cost claim is the sturdier of the two. The accuracy claim is the interesting
one, and the one worth measuring before anyone leans on it hard.
