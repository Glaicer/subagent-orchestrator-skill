---
name: opencode-orchestrator-subagents
description: Orchestrate non-trivial coding work in OpenCode with predefined architect, developer, and reviewer subagents. Use for spec-first planning, TDD implementation, review-driven fix loops, and final approval based on git diffs and tests.
compatibility: opencode
metadata:
  version: "1.0.0"
  target_agent: "opencode"
  companion_tool: "opencode-subagents"
  workflow: "architect-developer-reviewer"
---

# OpenCode subagent orchestration

## Use this skill when

Use this skill when OpenCode should act as the lead orchestrator for a non-trivial repository task while specialized OpenCode subagents handle planning, implementation, and review. This includes feature work, bug fixes, refactors that need a spec-first flow, test-driven implementation, security-sensitive changes, and review-driven coding loops.

Do not use this skill for a single trivial edit that the current agent can complete directly faster than setting up the task/review loop.

## Operating model

- The current OpenCode primary agent is the orchestrator. It owns repository state, session files, task sequencing, final decisions, and user-facing summaries.
- The `architect` subagent writes or revises the issue analysis, spec, plan, and detailed implementation tasks. It should not edit source code.
- The `developer` subagent implements exactly one assigned task or one assigned fix round using test-driven development where practical.
- The `reviewer` subagent performs spec review, code review, test review, and security review against actual repository state.
- Durable state lives in repository files, not chat memory.
- Git diff, tests, and review files are the source of truth.
- Never approve a task from a subagent summary alone. Inspect the actual diff and validation evidence.
- Do not allow the `developer` subagent to implement later tasks early.
- Avoid nested or recursive subagent work. The three supplied agents deny the `task` permission for themselves.

## Required subagents

This skill expects OpenCode agents with these exact file/agent names:

- `architect` — planning/spec/task agent, preferably `openai/gpt-5.5`, high reasoning effort, read-only.
- `developer` — implementation agent, preferably a small coding model such as `openai/gpt-5.4-mini`, edit-capable, TDD-oriented.
- `reviewer` — review agent, preferably `openai/gpt-5.5`, medium reasoning effort, read-only.

Project-local agents should live in:

```text
.opencode/agents/
  architect.md
  developer.md
  reviewer.md
```

Global agents can live in:

```text
~/.config/opencode/agents/
```

See `references/opencode-subagents.md` for the expected shape.

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

Before delegating to subagents, run:

```bash
git status --short

SESSION_TIMESTAMP="${SESSION_TIMESTAMP:-$(date -u +%Y%m%dT%H%M%SZ)}"
AGENT_DIR=".agent/${SESSION_TIMESTAMP}"
mkdir -p "${AGENT_DIR}/tasks" "${AGENT_DIR}/reviews" "${AGENT_DIR}/logs"

missing_agents=()
for agent in architect developer reviewer; do
  if [ ! -f ".opencode/agents/${agent}.md" ] && [ ! -f "$HOME/.config/opencode/agents/${agent}.md" ]; then
    missing_agents+=("${agent}")
  fi
done

if [ "${#missing_agents[@]}" -gt 0 ]; then
  printf 'Missing OpenCode agents: %s\n' "${missing_agents[*]}"
  printf 'Install them under .opencode/agents/ or ~/.config/opencode/agents/ before continuing.\n'
  exit 1
fi
```

If the working tree already has unrelated user changes, preserve them. Do not overwrite, revert, or reformat unrelated files. Record the initial dirty state in `${AGENT_DIR}/status.md`.

## Planning phase

Write or update these files before implementation:

1. `${AGENT_DIR}/issue.md` — concise restatement of the issue and user intent.
2. `${AGENT_DIR}/status.md` — session timestamp, current phase, dirty-state notes, blocked items, and next required action.

Then use the Task tool to invoke the `architect` subagent. Ask it to inspect the repository as needed and return:

1. A spec with desired behavior, non-goals, constraints, compatibility notes, security considerations, and acceptance criteria.
2. An ordered plan with task IDs, dependencies, expected files, validation checks, and rollback/migration concerns if relevant.
3. One detailed task prompt per task.

The primary OpenCode agent must review the architect output before writing it to disk. Save the architect result in `${AGENT_DIR}/logs/architect.round-1.result.md`, then write:

1. `${AGENT_DIR}/spec.md`
2. `${AGENT_DIR}/plan.md`
3. `${AGENT_DIR}/tasks/TNNN.md` for each task

Each task must be independently reviewable. Prefer small tasks that can be validated by targeted tests.

## Architect delegation prompt

Use this shape when invoking the `architect` subagent:

```md
You are the architect subagent for this repository task.

Read the user request, current repository state, and any existing files under `${AGENT_DIR}`.
Do not edit source code.

Return:

1. `spec.md` content with desired behavior, non-goals, constraints, compatibility, security considerations, and acceptance criteria.
2. `plan.md` content with ordered task IDs, dependencies, expected files, and validation checks.
3. One implementation task prompt per task, suitable for the `developer` subagent.

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
2. Invoke the `developer` subagent for exactly one task.
3. Save the developer result in `${AGENT_DIR}/logs/`.
4. Capture `git status --short` and `git diff` after the developer finishes.
5. Run relevant tests, lint, typecheck, and security checks.
6. Invoke the `reviewer` subagent for the task round.
7. Save the reviewer result to `${AGENT_DIR}/reviews/TASK.round-N.review.md`.
8. Inspect the diff, checks, and review before accepting the decision.
9. If approved, mark the task done and continue.
10. If changes are required, write a concrete fix prompt and invoke the `developer` subagent for another round.
11. Stop for the user if a task exceeds three fix rounds, tests cannot be run, a subagent fails ambiguously, or a security concern is unresolved.

Default to one active implementation task at a time, because multiple writers in the same worktree can create conflicts. Parallelize only read-only architecture/review work, or use separate worktrees when the user explicitly asks for parallel implementation.

## Developer delegation: implement one task

Use this prompt shape when invoking the `developer` subagent. Replace task IDs as needed.

```md
You are the developer subagent. Implement exactly one task using test-driven development where practical.

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
5. If a test cannot be added or run, explain exactly why.

When done, summarize changed files, tests/checks run, results, and remaining concerns.
Do not mark the task approved.
```

## Developer delegation: fix one reviewed task

After writing `${AGENT_DIR}/reviews/T001.round-1.review.md` and `${AGENT_DIR}/tasks/T001.round-2.fix.md`, invoke `developer` with this shape:

```md
You are the developer subagent. Apply only the required fixes for `T001` round 2.

Read:

- `${AGENT_DIR}/issue.md`
- `${AGENT_DIR}/spec.md`
- `${AGENT_DIR}/plan.md`
- `${AGENT_DIR}/tasks/T001.md`
- `${AGENT_DIR}/reviews/T001.round-1.review.md`
- `${AGENT_DIR}/tasks/T001.round-2.fix.md`

Rules:

- Fix only `T001`.
- Do not implement later tasks.
- Do not make unrelated refactors.
- Preserve unrelated user changes.
- Add or update tests if the fix changes behavior or covers a missed edge case.

When done, summarize what changed, changed files, tests/checks run, and remaining concerns.
Do not mark the task approved.
```

## After each developer round

Capture the implementation diff and working tree status:

```bash
: "${AGENT_DIR:?AGENT_DIR must be set}"

TASK_ID="T001"
ROUND="1"

git diff -- . ':!.agent' > "${AGENT_DIR}/logs/${TASK_ID}.round-${ROUND}.diff"
git status --short > "${AGENT_DIR}/logs/${TASK_ID}.round-${ROUND}.status.log"
```

Run the project checks. Stop for the user if a required check exists but cannot be run, or if the absence of checks makes approval unsafe.

## Reviewer delegation prompt

Use this shape when invoking the `reviewer` subagent:

```md
You are the reviewer subagent. Review actual repository state for `T001` round 1.

Read:

- `${AGENT_DIR}/issue.md`
- `${AGENT_DIR}/spec.md`
- `${AGENT_DIR}/plan.md`
- `${AGENT_DIR}/tasks/T001.md`
- `${AGENT_DIR}/logs/T001.round-1.diff`
- `${AGENT_DIR}/logs/T001.round-1.status.log`
- any test/lint/typecheck/security logs generated for this round
- relevant source files touched by the diff

Return the review contract from `references/review-contract.md` with:

Decision: approve | request_changes | block

Review spec compliance, security, code quality, and tests. Do not modify files.
```

## Review decision handling

Write reviews to `${AGENT_DIR}/reviews/TASK.round-N.review.md` using `references/review-contract.md`.

- `approve`: mark the task done only after the primary OpenCode agent also inspects the diff and agrees.
- `request_changes`: write a fix prompt with concrete required changes, then invoke `developer` again.
- `block`: stop and ask the user for the required decision or risk acceptance.

## Final review

After all tasks are approved:

1. Run the broadest reasonable test suite and checks for the repository.
2. Review the full final diff against `${AGENT_DIR}/spec.md` and `${AGENT_DIR}/plan.md`.
3. Record the final status in `${AGENT_DIR}/status.md`.
4. Summarize changed files, tests/checks run, risks, and remaining manual steps for the user.

Do not claim tests passed unless they were actually run and passed. If a check was skipped, state why.
