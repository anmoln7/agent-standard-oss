## What

<!-- One rule refinement or one script change per PR (see CONTRIBUTING.md). -->

## Evidence

<!-- For a script change: paste the before/after of a REAL run showing it does what
     it claims. For a STANDARD.md change: say what drift the rule prevents. -->

```
(paste run output here)
```

## Checklist

- [ ] `tests/run-tests.sh` passes
- [ ] `shellcheck -S warning` is clean on any touched script
- [ ] No personal config (email, token, org id, private repo name) — CI will reject it
