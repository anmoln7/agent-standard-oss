---
status: draft
target: STANDARD.md §10 (Guardrails and recovery)
date: 2026-08-08
tags: [stop-condition, defaults, sandbox, autonomy, guardrails]
see_also: bidirectional-model-routing.md
---

# Proposal: audit the default, not just the policy

**Status: draft. Not adopted. Nothing in `STANDARD.md` depends on this file.**

## The gap

§10 already carries the five stop-condition questions, verification-bounded
autonomy, least-privilege tools, layered guards, and the retry-storm rule. This
proposal does not change any of that.

What §10 assumes is that the operator authors the stop policy. It does not say
that **the tool already answered those five questions before the operator showed
up.** Every agent framework, CI runner, and harness ships defaults for turn caps,
spend caps, sandboxing, and verification hooks. An unset field is not a neutral
absence — it is a policy someone else wrote, tuned for a demo rather than for
your blast radius.

The failure mode is not "the team skipped the policy." It is "the team wrote a
policy and inherited a permissive default underneath it."

This is the same idea as §1's *enforced beats written*, one level down: written
beats nothing, enforced beats written, and **the default beats all three when
nobody reads it**.

The unset default is the sharpest case, but not the only one. Every line already
in an AGENTS.md is one of three things: a **fact** someone verified, a
**convention** nobody has re-checked since it was inherited, or an **unknown**
asserted as if it were settled. A stop policy hardens against the unset field; it
does nothing for a line that reads confident but was never true — "we always
sandbox," "the harness caps turns" — when the surface underneath defaults the
other way. Auditing the policy means tagging its load-carrying lines by which of
the three they are, and re-checking every one still marked convention.

For each convention that carries weight, the audit is not done at "what breaks if
this is wrong." Ask the other half too: **what opens up if it's false.** "We always
run in-process" broken isn't only a hole to close — inverted, it's the sandbox you
could have been shipping on by default. The defensive read finds the gap; the
inverted read finds the better default you were one config line away from.

There is a third trigger for this audit, and it fires on its own. A weak or generic
agent result is itself evidence that an instruction line was underspecified — not a
reason to re-roll the same generation. When the output comes back polished and
useless, the fix is upstream: find the AGENTS.md line that left "good" undefined and
sharpen it, then re-run. The result is a mirror of the instruction; treat a bad one
as a pointer back to the spec, not as noise to retry through.

One caution sits under all three triggers. When the audit reports that something is
**absent** — a control, a convention, a required line — where you looked decides
whether that silence means anything. An unknown becomes a "not found" only when the
surface the thing would live on is one the repo actually owns: a missing backup rule
is a real gap in infrastructure the repo ships, but nothing at all in application
code that would never carry it. Outside the surface it owns, silence stays unknown —
never reported as absent. An audit that skips this promotes every gap it failed to
search into a false absence, which is the same confident-but-untrue failure the
three-state frame exists to catch.

## Evidence

Findings from a source audit of NVIDIA-labs OO Agents (NOOA, `NVIDIA-NeMo/labs-OO-Agents`,
Apache 2.0), read at commit state of the `main` snapshot dated 2026-08-07. It is a
serious, well-engineered framework from a serious vendor — which is what makes it
useful evidence. This is not a criticism of that project; a research framework is
entitled to permissive defaults. The point is what a downstream team inherits.

Machinery that exists and is genuinely good:

- `src/nooa/strategy_validation.py` — per-method `preconditions` (fail-fast before
  generation) and `postconditions` raising `InvariantError`, explicitly
  *"model-correctable"* and routed back into the retry loop as feedback. A real
  verifier hook for checks that type validation cannot express.
- `src/nooa/runtime/sandbox/guards.py` — Landlock path rules, seccomp-BPF blocking
  `socket(AF_INET/AF_INET6)`, `RLIMIT_AS` / `RLIMIT_CPU`, and
  `prctl(PR_SET_NO_NEW_PRIVS)`, applied by the worker to itself after fork,
  before any cell runs. A genuine OS-level containment boundary.
- `SandboxConfig.require: bool = True` — fails closed with `SandboxUnavailable`
  rather than running with a guard silently missing. The docstring calls this
  *"deliberate."*

What that machinery does when you set nothing:

| Stop-policy question (§10) | Surface that exists | Default |
|---|---|---|
| What may it touch? | Landlock rules, `@hidden`, `RestrictionsConfig` | Linux-only; `DEFAULT_RESTRICTED_IMPORTS = frozenset()` (empty) |
| How long may it run? | `max_iterations`, `cell_timeout` | `None` — the vendor's own skill doc states **"Unlimited."** |
| What is the spend cap? | — | Does not exist (no `spend_cap` / `cost_limit` / `max_cost` across 281 source files) |
| What counts as proof? | `postconditions` | `()` — empty |
| What must it record? | tracing, ATIF export | On only when the dev viewer runs |
| When does a human get pulled in? | — | No escalation primitive |
| Where does code execute? | `execution_backend` | `"inprocess"` — the sandbox is opt-in |

The loop-exhaustion check is the clearest instance
(`src/nooa/strategies/codeact.py`, `CodeActSession.is_exhausted`): it returns
`True` only when `max_iterations is not None and ...`. The sole default backstop
is `max_retries = 3` on **consecutive errors** — a loop that keeps succeeding at
useless work never trips it.

Worth noting the vendor's own guidance is sound and states the standard's
position well: *"`max_iterations` is a safety net, not the main tuning dial —
decompose the task instead of raising the cap."* The guidance is right; the
default does not implement it.

## Proposed change 1 — new bullet in §10

Place after the existing *"The stop condition is a policy, not a parameter"* bullet.

> - **An unset default is a policy someone else wrote.** The five questions above
>   have answers *before* you write anything — your agent framework, CI runner,
>   and harness all ship defaults for turn caps, spend caps, sandboxing, and
>   verification hooks. Those defaults are tuned for demos, not for your blast
>   radius: shipped frameworks routinely default to unlimited iterations, no spend
>   ceiling, in-process execution, and empty verifier hooks, while shipping
>   excellent sandbox and invariant machinery that is *opt-in*. So the stop policy
>   isn't done when it's written — it's done when you have diffed it against what
>   the tool does when the field is absent. Read the config's defaults, not its
>   feature list. A capability that exists but defaults off protects nobody.

## Proposed change 2 — platform caveat

Either as a sub-point of the above or in `SECURITY.md`. This is the finding most
likely to bite in day-to-day work.

> Confirm the guardrail is enforceable *on the machine that runs it*. OS-level
> containment is typically Linux-only (Landlock, seccomp, rlimits); on macOS dev
> machines those probe unavailable, so the harness either refuses to start or runs
> with the guards silently dropped. Prefer the fail-closed setting; treat "it
> worked on my laptop" as evidence the sandbox was **not** active.

Concretely, in the audited framework: `runtime/sandbox/executor.py` returns
`["sandbox requires Linux"]` and, with `require=False`, logs *"sandbox running
with UNENFORCED guardrails."* The `start_method` is `Literal["fork"]` only,
because the worker inherits the live agent and the `return_result` closure,
neither of which pickles for `spawn`. On a Mac, the containment boundary does not
exist — the dev-machine posture is the unsafe one.

## Deliberately not proposed

- **No new `STD-0x` check.** The check IDs are a stated contract, and §1's scoring
  section is explicit that a deterministic scan "can confirm a file exists,
  parses, and matches a pattern — never that its contents are *true*." Auditing
  whether an inherited default is appropriate is precisely the judgment work that
  section says no scanner can do. Adding a check here would be the false green it
  warns about.
- **No vendor case study in `STANDARD.md`.** The standard is a house standard, not
  a survey. Naming a specific framework's defaults dates the document fast — those
  defaults may well change. The generalized bullet carries the lesson; the
  evidence lives here.
- **No changes to the five questions themselves.** They are correct as written.

## If picked up

1. Re-verify the evidence table against the current release — the specific
   defaults are a snapshot and the project is under active development. The
   *pattern* is the durable claim, not the individual values.
2. Apply change 1 to §10; decide whether change 2 belongs in §10 or `SECURITY.md`.
3. Add a `CHANGELOG.md` entry and bump `VERSION` per the repo's normal flow.
4. Consider whether `templates/docs/EXAMPLE-acceptance-criteria.md` should gain a
   line prompting for inherited defaults alongside the four existing fields.
