# Acceptance Criteria Contract — <task name>

The unit of work for an agent task: what "done" means, written *before* the loop
runs, so the task is a contract instead of a vibe (STANDARD.md §10). Keep it to
half a page. It doubles as the verifier — review the output against this, not the
diff line by line.

Copy this file per task (or paste it into the dispatch prompt / the loop config).
Delete the guidance lines; keep the four fields.

## Objective
What it accomplishes in **user-visible terms**, not implementation terms.
- Good: "A valid user signs in and reaches the dashboard in under 2s; an invalid
  attempt errors in under 1s."
- Bad: "Implement the auth flow."

## Constraints
What must **not** change: house conventions, dependencies to keep, performance
budgets, regulatory requirements, architectural invariants. The fences the agent
stays inside.

## Validation method
How we know it's done — a **command and a condition**, not "looks right" or "code
review approves it."
- Good: "`pytest tests/test_auth.py` passes, the e2e login flow runs green, p99
  stays under the SLO."
- The author is not the judge (§10): this must be checkable by something other
  than the agent that did the work.

## Escalation protocol
When the agent **stops and asks** instead of proceeding — the human-in-the-loop
trigger (§10's stop-condition policy).
- Example: "If the change touches payments, auth, or a migration, surface for
  review before proceeding."
