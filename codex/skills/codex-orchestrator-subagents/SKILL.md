---
name: codex-orchestrator-subagents
description: "Use this skill when Codex should orchestrate predefined Codex sub-agents: architect writes specs/plans/tasks, developer implements one task or fix round with TDD, reviewer performs code/spec/test/security review, and the parent Codex session repeats task-code-review cycles until the issue is finished."
compatibility: "Requires Codex subagent workflows and custom agents named architect, developer, and reviewer under ~/.codex/agents/ or .codex/agents/. Intended for local repository worktrees. Prefer workspace-write for the parent session, read-only for architect/reviewer, and workspace-write for developer."
metadata:
  version: "1.0.0"
  target_agent: codex
  companion_tool: codex-subagents
  workflow: architect-developer-reviewer
---

# Codex sub-agent orchestration

## Use this skill when

Use this skill when the user wants Codex to act as the lead orchestrator for a non-trivial coding issue while specialized Codex sub-agents handle planning, implementation, and review. This includes multi-step feature work, bug fixes that need a spec-first flow, test-driven implementation, review-driven coding, and local multi-agent workflows where Codex can inspect and modify a repository.

Do not use this skill for a single trivial edit that the parent Codex session can complete directly faster than setting up the task/review loop.

## Operating model

- Parent Codex is the orchestrator. It owns repository state, session files, task sequencing, final decisions, and user-facing summaries.
- The `architect` sub-agent writes or revises the issue analysis, spec, plan, and detailed implementation tasks (e.g. `T001.md`, `T002.md`, etc. inside `.agent/${SESSION_TIMESTAMP}/tasks/`). It should not edit source code.
- The `developer` sub-agent implements exactly one assigned task or one assigned fix round. It must use test-driven development where practical.
- The `reviewer` sub-agent performs spec review, code review, test review, and security review against actual repository state.
- Durable state lives in repository files, not chat memory.
- Git diff, tests, and review files are the source of truth.
- Never approve a task from a sub-agent summary alone; inspect the actual diff and validation evidence.
- Do not allow the `developer` sub-agent to implement later tasks early.
- Keep sub-agent nesting shallow. The recommended Codex setting is `agents.max_depth = 1`, so child agents do not recursively spawn their own children.

## Required sub-agents

This skill expects custom Codex agents with these exact `name` values:

- `architect` — planning/spec/task agent, preferably `gpt-5.5`, high reasoning effort, read-only.
- `developer` — implementation agent, preferably a small coding model such as `gpt-5.4-mini`, high reasoning effort, workspace-write, TDD-oriented.
- `reviewer` — review agent, preferably `gpt-5.4`, medium reasoning effort, read-only.

Custom agents should be defined as standalone TOML files under either `~/.codex/agents/` or `.codex/agents/`. See `references/codex-subagents.md` for the expected shape.

Recommended project config:

```toml
[agents]
max_threads = 6
max_depth = 1
```

## Repository state layout

At the start of each orchestration session, initialize a single `SESSION_TIMESTAMP` and derive `AGENT_DIR` from it. Keep both values unchanged throughout the session.

```bash
SESSION_TIMESTAMP="${SESSION_TIMESTAMP:-$(date -u +%Y%m%dT%H%M%SZ)}"
AGENT_DIR=".agent/${SESSION_TIMESTAMP}"

mkdir -p "${AGENT_DIR}/tasks" "${AGENT_DIR}/reviews" "${AGENT_DIR}/logs"
```

Create this directory structure at the repository root:

```text
.agent/${SESSION_TIMESTAMP}/
  issue.md
  spec.md
  plan.md
  status.md
  tasks/
    T001.md
    T002.md
    T001.round-2.fix.md
  reviews/
    T001.round-1.review.md
  logs/
    architect.round-1.result.md
    T001.round-1.developer.result.md
    T001.round-1.diff
    T001.round-1.status.log
    T001.round-1.tests.log
```

Use `assets/task-prompt-template.md` for implementation task prompts and `assets/fix-prompt-template.md` for fix rounds.

## Preflight

Before delegating to sub-agents, run:

```bash
git status --short

SESSION_TIMESTAMP="${SESSION_TIMESTAMP:-$(date -u +%Y%m%dT%H%M%SZ)}"
AGENT_DIR=".agent/${SESSION_TIMESTAMP}"
mkdir -p "${AGENT_DIR}/tasks" "${AGENT_DIR}/reviews" "${AGENT_DIR}/logs"

missing_agents=()
for agent in architect developer reviewer; do
  if ! { grep -R "^[[:space:]]*name[[:space:]]*=[[:space:]]*\"${agent}\"" .codex/agents "$HOME/.codex/agents" 2>/dev/null || true; } | grep -q .; then
    missing_agents+=("${agent}")
  fi
done

if [ "${#missing_agents[@]}" -gt 0 ]; then
  printf 'Missing Codex custom agents: %s\n' "${missing_agents[*]}"
  printf 'Create TOML files for these agents under .codex/agents/ or ~/.codex/agents/ before continuing.\n'
  exit 1
fi
```

If the working tree already has unrelated user changes, preserve them. Do not overwrite, revert, or reformat unrelated files. Record the initial dirty state in `${AGENT_DIR}/status.md`.

## Planning phase

Write or update the following files before implementation:

1. `${AGENT_DIR}/issue.md` — concise restatement of the issue and user intent.
2. `${AGENT_DIR}/status.md` — session timestamp, current phase, dirty-state notes, blocked items, and next required action.

Then spawn the `architect` sub-agent and ask it to inspect the repository as needed and return:

1. A spec with desired behavior, non-goals, constraints, compatibility notes, security considerations, and acceptance criteria.
2. An ordered plan with task IDs, dependencies, expected files, validation checks, and rollback/migration concerns if relevant.
3. One detailed task prompt per task.

The parent Codex session must review the architect output before writing it to disk. Save the architect result in `${AGENT_DIR}/logs/architect.round-1.result.md`, then write:

1. `${AGENT_DIR}/spec.md`
2. `${AGENT_DIR}/plan.md`
3. `${AGENT_DIR}/tasks/TNNN.md` for each task

Each task must be independently reviewable. Prefer small tasks that can be validated by targeted tests.

## Architect delegation prompt

Use this shape when spawning the `architect` sub-agent:

```md
You are the architect sub-agent for this repository task.

Read the user request, current repository state, and any existing files under `${AGENT_DIR}`.
Do not edit source code.

Return:

1. `spec.md` content with desired behavior, non-goals, constraints, compatibility, security considerations, and acceptance criteria.
2. `plan.md` content with ordered task IDs, dependencies, expected files, and validation checks.
3. One implementation task prompt per task, suitable for the `developer` sub-agent.

Task rules:

- Tasks must be small and independently reviewable.
- Each task must say what tests should be written or updated.
- Each task must explicitly say not to implement later tasks.
- Call out ambiguous requirements as blockers instead of guessing.
```

If the architect reports blockers, stop and ask the user only for the missing decision. Do not proceed to implementation on an ambiguous spec.

## Implementation loop

For each task:

1. Update `${AGENT_DIR}/status.md` to show the current task and round.
2. Spawn the `developer` sub-agent for exactly one task.
3. Save the developer result in `${AGENT_DIR}/logs/`.
4. Capture `git status --short` and `git diff` after the developer finishes.
5. Run relevant tests, lint, typecheck, and security checks.
6. Spawn the `reviewer` sub-agent for the task round.
7. Save the reviewer result to `${AGENT_DIR}/reviews/TASK.round-N.review.md`.
8. Parent Codex inspects the diff, checks, and review before accepting the decision.
9. If approved, mark the task done and continue.
10. If changes are required, write a concrete fix prompt and spawn the `developer` sub-agent for another round.
11. Stop for the user if a task exceeds three fix rounds, tests cannot be run, a sub-agent fails ambiguously, or a security concern is unresolved.

Default to one active implementation task at a time, because multiple writers in the same worktree can create conflicts. Parallelize only read-only architecture/review work, or use separate worktrees when the user explicitly asks for parallel implementation.

## Sub-agent run behavior

When the parent Codex session spawns the `developer` sub-agent, treat it as an opaque implementation step until it returns.

While the `developer` sub-agent is running:

- Do not repeatedly inspect partial edits.
- Do not steer the sub-agent unless it explicitly asks for clarification or approval.
- Do not start another write-capable implementation in the same worktree.

After the sub-agent returns, continue with:

1. capture git status,
2. capture git diff,
3. run checks,
4. delegate review,
5. inspect the review and repository state.

## Developer delegation: implement one task

Use this prompt shape when spawning the `developer` sub-agent. Replace task IDs as needed.

```md
You are the developer sub-agent. Implement exactly one task using test-driven development where practical.

Source of truth:

- `${AGENT_DIR}/issue.md`
- `${AGENT_DIR}/spec.md`
- `${AGENT_DIR}/plan.md`
- `${AGENT_DIR}/tasks/T001.md`

Scope:

- Implement only `T001`.
- Do not implement later tasks.
- Do not perform unrelated refactors.
- Preserve unrelated user changes.

TDD expectations:

1. Identify the smallest meaningful failing test or test update for this task.
2. Add or update that test first when the repository has a viable test harness.
3. Make the smallest implementation that satisfies the task.
4. Run the targeted test/check for the change.
5. Report changed files, tests/checks run, and any remaining concerns.

Do not mark the task approved. The parent Codex session and reviewer sub-agent will review the diff.
```

## Developer delegation: fix one reviewed task

After `${AGENT_DIR}/reviews/T001.round-1.review.md` and `${AGENT_DIR}/tasks/T001.round-2.fix.md` exist, spawn the `developer` sub-agent with this prompt shape:

```md
You are the developer sub-agent. Apply only the required fixes for `T001` round 2.

Source of truth:

- `${AGENT_DIR}/issue.md`
- `${AGENT_DIR}/spec.md`
- `${AGENT_DIR}/plan.md`
- `${AGENT_DIR}/tasks/T001.md`
- `${AGENT_DIR}/reviews/T001.round-1.review.md`
- `${AGENT_DIR}/tasks/T001.round-2.fix.md`

Scope:

- Fix only `T001`.
- Do not implement later tasks.
- Do not make unrelated refactors.
- Preserve already-correct work.
- Add or update tests if the fix changes behavior or covers a missed edge case.

Report what was fixed, changed files, tests/checks run, and any remaining concerns.
```

## After each developer run

Capture the implementation diff and working tree status:

```bash
: "${AGENT_DIR:?AGENT_DIR must be set}"

TASK_ID="T001"
ROUND="1"

git diff -- . ':!.agent' > "${AGENT_DIR}/logs/${TASK_ID}.round-${ROUND}.diff"
git status --short > "${AGENT_DIR}/logs/${TASK_ID}.round-${ROUND}.status.log"
```

Run the project checks. Stop for the user if a required check exists but cannot be run, or if the absence of checks makes approval unsafe.

Save the developer's returned summary as:

```text
${AGENT_DIR}/logs/${TASK_ID}.round-${ROUND}.developer.result.md
```

## Reviewer delegation prompt

Spawn the `reviewer` sub-agent after each developer round. Use this prompt shape:

```md
You are the reviewer sub-agent for `T001` round 1.

Review actual repository state, not only the developer summary.

Required inputs:

- `${AGENT_DIR}/issue.md`
- `${AGENT_DIR}/spec.md`
- `${AGENT_DIR}/plan.md`
- `${AGENT_DIR}/tasks/T001.md`
- `${AGENT_DIR}/logs/T001.round-1.diff`
- `${AGENT_DIR}/logs/T001.round-1.status.log`
- `${AGENT_DIR}/logs/T001.round-1.tests.log` if present
- relevant source files touched by the diff

Perform:

1. Spec review.
2. Security review.
3. Code review.
4. Test review.

Return a review in the exact decision format from `references/review-contract.md`.
Use `approve` only when the task satisfies its acceptance criteria, introduces no unacceptable risk, and has adequate validation for the repository context.
Use `request_changes` when the developer can safely fix concrete issues.
Use `block` when the issue needs human judgment.
```

## Review checklist

Before approving a task, ensure the review covered:

### Spec review

- Does the diff satisfy every task acceptance criterion?
- Did the developer avoid future tasks and unrelated refactors?
- Did behavior remain backward-compatible unless the spec explicitly allows a breaking change?

### Security review

Check for auth bypasses, access-control regressions, injection risks, SSRF, path traversal, unsafe deserialization, weak crypto, secret leakage, overbroad logging, dependency risk, unsafe shell execution, and permission broadening.

### Code review

Check maintainability, local conventions, error handling, edge cases, concurrency/race concerns, performance risks, migration safety, and API boundaries.

### Test review

Check whether tests meaningfully cover success paths, failures, edge cases, and regressions. If tests are missing or weak, request changes unless there is a clear reason not to.

## Review decision format

Write reviews to `${AGENT_DIR}/reviews/TASK.round-N.review.md` using this structure:

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

Use `request_changes` when the developer can safely fix the problem. Use `block` when the issue is ambiguous, risky, or requires human decision-making.

Sub-agent result logs are diagnostic artifacts, not review artifacts. The parent Codex session and reviewer should review repository state, diffs, status, checks, task prompts, the spec, and the plan.

Only inspect full sub-agent logs if:

- the sub-agent failed,
- the diff is empty or suspicious,
- tests fail and the cause is unclear,
- the review contradicts the observed diff,
- or the user explicitly asks to inspect sub-agent logs.

When logs must be inspected, read the smallest useful excerpt first.

## Status updates

After every major step, update `${AGENT_DIR}/status.md`:

```md
# Agent status

Session timestamp: 20260504T120000Z
Agent directory: .agent/20260504T120000Z
Implementer: developer sub-agent
Planner: architect sub-agent
Reviewer: reviewer sub-agent
Current task: T001
Current round: 1
State: reviewing
Approved tasks: none
Blocked items: none
Last action: Developer sub-agent completed T001 and checks were run.
Next required action: Reviewer sub-agent review of T001 diff, tests, and security.
```

## Completion

After all tasks are approved:

1. Review the full branch diff against `${AGENT_DIR}/spec.md`.
2. Run the full test suite and project checks.
3. Spawn the `reviewer` sub-agent for a final full-branch review if the change is non-trivial.
4. Write `${AGENT_DIR}/final-review.md`.
5. Mark `${AGENT_DIR}/status.md` as finished only if the final review passes.

Final review must include:

- implemented tasks
- checks run and results
- residual risks
- any user follow-up required
- final decision: `finished` or `blocked`

## Hard stops

Stop and ask the user before continuing if:

- Required custom agents `architect`, `developer`, or `reviewer` are missing.
- A sub-agent asks for broad or dangerous permissions that were not explicitly authorized.
- More than three review/fix rounds are needed for one task.
- A required check exists but cannot be run.
- The absence of tests or checks makes approval unsafe.
- The diff touches secrets, credentials, auth, payments, data deletion, migrations, or production infrastructure in a way not explicitly covered by the spec.
- The repository has unrelated dirty changes that could be overwritten.
