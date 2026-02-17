## Summary

### What changed

<!-- Describe the change in 2-5 bullets. -->

### Why this change

<!-- Explain the problem, motivation, or user impact. -->

## Scope

<!-- Mark every area touched by this PR. -->

- [ ] `packages/**` (Cairo/Starknet components)
- [ ] Other (docs/chore/infra only)

## Change Type

- [ ] `feat` (new behavior)
- [ ] `fix` (bug fix)
- [ ] `refactor` (no behavior change)
- [ ] `perf` (performance improvement)
- [ ] `test` (tests only)
- [ ] `docs` (documentation only)
- [ ] `chore` (maintenance/tooling)

## Validation

### Commands run

<!-- Paste exact commands run and summarize results. -->

```bash
# example:
# scarb build && snforge test <module>
```

### Area-specific verification

#### If `packages/**` changed

- [ ] `scarb build`
- [ ] `snforge test <module>` (or targeted tests listed below)
- [ ] `scarb fmt --check --workspace`
- [ ] Security-sensitive paths (auth, external calls, arithmetic, state transitions) reviewed

## Risk and Rollout

### Risk level

- [ ] Low
- [ ] Medium
- [ ] High

### Rollout / rollback plan

<!-- Describe deployment sequencing, feature flags, and rollback steps if needed. -->

## Breaking Changes

- [ ] No breaking changes
- [ ] Breaking changes included (describe below)

<!-- If breaking: include migration steps, compatibility notes, and owner notifications. -->

## Assumptions

<!-- List assumptions made while implementing this PR. Include how each was validated (or why it could not be validated). -->

- Assumption:
  Validation:

## Exceptions

<!-- List any deviations from normal standards/process (lint/test gaps, temporary policy exceptions, non-standard patterns). -->

- Exception:
  Reason:
  Approval/Context:

## Workarounds

<!-- List temporary fixes or compromises introduced to unblock delivery. -->

- Workaround:
  Why needed:
  Removal plan (owner + trigger/date):

## Linked Issues

<!-- Closes #123, Related #456 -->

## Reviewer Notes

<!-- Include anything reviewers should focus on first. -->

### AI review routing

- Cairo review: `packages/**`
- General review: everything outside `packages/**`
