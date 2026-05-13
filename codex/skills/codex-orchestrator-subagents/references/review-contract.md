# Review contract

Codex must review actual repository state, not only sub-agent summaries.

## Required inputs

For each task round, review:

- `${AGENT_DIR}/issue.md`
- `${AGENT_DIR}/spec.md`
- `${AGENT_DIR}/plan.md`
- `${AGENT_DIR}/tasks/TNNN.md`
- `${AGENT_DIR}/logs/TNNN.round-N.diff`
- `${AGENT_DIR}/logs/TNNN.round-N.status.log`
- test/lint/typecheck/security logs that were generated for the round
- relevant source files touched by the diff

## Decision meanings

### approve

Use only when the task satisfies its acceptance criteria, does not introduce unacceptable risk, and has adequate validation for the repository context.

### request_changes

Use when the developer sub-agent can safely fix concrete issues without a human decision.

Each required change must be specific enough for the developer sub-agent to act on.

### block

Use when:

- the spec is ambiguous
- a security risk requires human judgment
- tests/checks cannot be run and approval would be unsafe
- the developer sub-agent repeatedly fails
- implementation requires broader product or architecture decisions

## Review file template

```md
# Review: T001 round 1

Decision: approve | request_changes | block

## Summary

...

## Spec review

- Passed: yes/no
- Findings:

## Security review

- Passed: yes/no
- Findings:

## Code review

- Passed: yes/no
- Findings:

## Test review

- Passed: yes/no
- Findings:

## Required changes

1. ...

## Recommended changes

1. ...

## Next step

mark_task_done | call_developer_again | stop_for_human
```

## Approval checklist

Before `approve`, verify:

- The diff is scoped to the current task.
- The task acceptance criteria are satisfied.
- The implementation did not silently implement future tasks.
- Existing behavior remains compatible unless the spec says otherwise.
- Security-sensitive changes are covered by the spec and reviewed directly.
- Test coverage is reasonable for the change.
- Generated logs truthfully record checks that passed, failed, or were skipped.
