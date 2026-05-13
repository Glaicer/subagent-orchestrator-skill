# OpenCode subagent reference for this skill

Use this file when configuring or invoking OpenCode subagents for this orchestration workflow.

## Expected custom agents

This skill assumes these custom agent names exist:

- `architect`
- `developer`
- `reviewer`

In OpenCode Markdown agent configuration, the Markdown filename becomes the agent name:

```text
.opencode/agents/
  architect.md
  developer.md
  reviewer.md
```

Personal/global agents can live in:

```text
~/.config/opencode/agents/
```

Project-scoped agents can live in:

```text
.opencode/agents/
```

## Required Markdown shape

Each agent file uses YAML frontmatter followed by the agent prompt:

```md
---
description: Implements scoped coding tasks using TDD.
mode: subagent
model: openai/gpt-5.4-mini
reasoningEffort: medium
permission:
  edit: allow
  bash: ask
  task: deny
---

You are the Developer subagent.
...
```

The `model` value uses OpenCode's `provider/model-id` format. Run this to see available local model IDs:

```bash
opencode models
```

Provider-specific options such as `reasoningEffort` are passed through to the provider. Keep them only for providers/models that support them.

## Optional project config

If you want to restrict which subagents a primary agent can call, add an `opencode.json` file in the repository root:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "skill": {
      "*": "ask",
      "opencode-orchestrator": "allow"
    },
    "task": {
      "*": "deny",
      "architect": "allow",
      "developer": "allow",
      "reviewer": "allow"
    }
  }
}
```

Adjust this if your normal workflow needs other subagents.

## Invocation guidance

OpenCode primary agents can invoke subagents automatically based on description or manually with `@agent-name`. For orchestration, the primary agent should use the Task tool when available, wait for the child result, and then consolidate or act on it.

Use prompts such as:

```text
Invoke the `architect` subagent to inspect the repository and return a spec, plan, and task prompts. Do not edit source code.
```

```text
Invoke the `developer` subagent to implement only T001 using the files under .agent/<timestamp>. Use TDD where practical and do not implement later tasks.
```

```text
Invoke the `reviewer` subagent to review T001 round 1 against the spec, diff, status, tests, and touched source files. Return the review-contract format.
```

## Safety

- The primary OpenCode agent owns sequencing and final acceptance.
- Reviewer and architect should usually be read-only.
- Developer may need edit permission.
- Avoid parallel write-capable agents in the same worktree.
- Inspect actual diffs and checks before approval.
- Treat subagent summaries as hints, not proof.
