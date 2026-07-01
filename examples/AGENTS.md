# Acme Widget API — Agent Guide

<!--
  A worked example of an AGENTS.md following this standard.
  CLAUDE.md in the same repo is a single line: @AGENTS.md
-->

One-sentence description: a REST API that serves widget inventory to the storefront.

## Architecture

Where the code lives and the 3–5 things to understand before editing:

- `src/routes/` — HTTP handlers. `src/services/` — business logic. `src/db/` — Prisma layer.
- Auth is a middleware in `src/middleware/auth.ts`; every `/admin/*` route checks it.
- The widget price is computed in `src/services/pricing.ts`, not stored — don't cache it.

## Commands

```bash
npm run dev        # local server on :3000
npm test           # unit tests (no DB needed)
npm run test:e2e   # end-to-end (needs a test DB)
npm run lint
```

## Conventions

- Match the existing route style; validate every input with the zod schemas in `src/schemas/`.
- Orphaned code NOT to recreate: `src/services/legacyPricing.ts` was removed — if you see
  an import of it, delete the import.

## Gotchas

The traps. (Full past-incident write-ups live in [`docs/solutions/`](./docs/solutions/).)

- The Stripe webhook must be registered in the dashboard pointing at `/api/webhooks/stripe`,
  or payments succeed but no order is created. See `docs/solutions/payments-webhook-missing.md`.

## Before shipping

`npm run lint && npm test` must pass. Run `npm run test:e2e` for any change under
`src/services/pricing.ts` or the checkout flow.

## Keep in sync

- Add an env var → document it here and in `.env.example`.
- Add a route → update the route list above and the README example.
- Change `src/schemas/*` → update the matching type in `src/types/` (the test that pins
  them will fail otherwise).

## Commit flow

Default: commit and push straight to `main`. Branch + PR only for schema migrations, large
refactors, or anything that could leave `main` undeployable (per the house standard §6).
