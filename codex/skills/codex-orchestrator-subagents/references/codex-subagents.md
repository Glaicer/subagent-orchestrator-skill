# Codex sub-agent reference for this skill

Use this file when configuring or invoking Codex sub-agents for this orchestration workflow.

## Expected custom agents

This skill assumes these custom agent names exist:

- `architect`
- `developer`
- `reviewer`

Codex identifies custom agents by the `name` field inside each TOML file, not by filename alone. Keeping filenames aligned with names is the simplest convention:

```text
.codex/agents/
  architect.toml
  developer.toml
  reviewer.toml
```

Personal agents can live in:

```text
~/.codex/agents/
```

Project-scoped agents can live in:

```text
.codex/agents/
```

## Required TOML fields

Each standalone custom agent TOML file must define:

```toml
name = "developer"
description = "Short human-facing guidance for when Codex should use this agent."
developer_instructions = """
Core behavior instructions for this agent.
"""
```

Useful optional overrides include:

```toml
model = "gpt-5.5"
model_reasoning_effort = "medium"
sandbox_mode = "read-only"
nickname_candidates = ["Atlas", "Delta", "Echo"]
```

## Recommended project settings

Add this to `.codex/config.toml` when the repository should opt into predictable shallow orchestration:

```toml
[agents]
max_threads = 6
max_depth = 1
```

`max_depth = 1` allows the parent Codex session to spawn direct child agents while preventing recursive fan-out from those children.

## Invocation guidance

Codex handles sub-agent orchestration in-session. The parent Codex session should explicitly ask for a named agent, wait for its result, and then consolidate or act on the result.

Use prompts such as:

```text
Spawn the `architect` sub-agent to inspect the repository and return a spec, plan, and task prompts. Do not edit source code.
```

```text
Spawn the `developer` sub-agent to implement only T001 using the files under .agent/<timestamp>. Use TDD where practical and do not implement later tasks.
```

```text
Spawn the `reviewer` sub-agent to review T001 round 1 against the spec, diff, status, tests, and touched source files. Return the review-contract format.
```

## Safety

- Parent Codex owns sequencing and final acceptance.
- Reviewer and architect should usually be read-only.
- Developer may need workspace-write.
- Avoid parallel write-capable agents in the same worktree.
- Inspect actual diffs and checks before approval.
- Treat sub-agent summaries as hints, not proof.
