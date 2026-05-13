# Fix round: {{TASK_ID}} round {{ROUND}}

## Role

You are the OpenCode `developer` subagent. Apply only the required fixes from the review.

## Source of truth

Read these files before editing:

- `${AGENT_DIR}/issue.md`
- `${AGENT_DIR}/spec.md`
- `${AGENT_DIR}/plan.md`
- `${AGENT_DIR}/tasks/{{TASK_ID}}.md`
- `${AGENT_DIR}/reviews/{{TASK_ID}}.round-{{PREV_ROUND}}.review.md`

## Scope

Fix only `{{TASK_ID}}`.

Do not implement later tasks. Do not make unrelated refactors. Do not modify unrelated files.

## Required fixes

{{REQUIRED_FIXES}}

## Constraints

- Preserve already-correct work.
- Keep changes minimal.
- Add or update tests if the fix changes behavior or covers a previously missed edge case.
- Do not bypass tests, validation, auth, or security checks.

## Completion response

When done, summarize:

1. What was fixed.
2. Changed files.
3. Tests/checks run.
4. Any remaining concerns.

Do not mark the task approved. The primary OpenCode agent and `reviewer` subagent will review the diff again.
