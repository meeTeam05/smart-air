---
name: planning-with-files
description: File-based planning for complex tasks. Creates and maintains task_plan.md, findings.md, and progress.md inside an active .planning plan directory. Use when asked to plan, break down, or organize multi-step work, especially tasks likely to require 5+ tool calls.
user-invocable: true
metadata:
  version: "local-smart-air-1"
---

# Planning with Files

Use persistent markdown files as working memory on disk for complex tasks.

## Plan Mode Compatibility

If Codex is running in Plan Mode or any mode that forbids file writes:

- do not create or update planning files
- do not treat this skill as permission to mutate the repo
- use in-context planning or `update_plan` instead
- if existing planning files already exist, you may read them for context
- resume file-backed planning only after returning to a write-allowed mode

## First: Recover Context

Before starting a complex task or after resuming:

```bash
$(command -v python3 || command -v python) .agents/skills/planning-with-files/scripts/session-catchup.py "$(pwd)"
```

If there is an existing plan:

1. Read `task_plan.md`
2. Read `findings.md`
3. Read `progress.md`
4. Continue from the current phase instead of restarting silently

## Core Files

Planning files live inside the active `.planning/<plan-id>/` directory.

| File | Purpose |
|------|---------|
| `task_plan.md` | Goal, phases, decisions, errors |
| `findings.md` | Research notes, discoveries, resources |
| `progress.md` | Session log, actions taken, test results |

## When to Use

Use this skill for:

- Multi-step implementation
- Research or debugging work
- Tasks with multiple phases or branching options
- Work likely to exceed 5 tool calls

Skip it for:

- Simple one-file edits
- Quick factual answers
- Tiny changes that do not need persistent tracking

## Task Intake

Classify the work before execution:

- `tiny`: skip this skill and patch directly unless the user explicitly wants persistent tracking
- `normal`: use the standard plan/progress/findings workflow
- `high-risk`: require locked decisions, validation evidence, and explicit exit criteria before implementation

## Required Workflow

Apply this workflow only when file writes are allowed.

1. Create `task_plan.md` first
2. Create `findings.md`
3. Create `progress.md`
4. Lock key assumptions and decisions for ambiguous or high-risk work
5. Validate the approach against real repo evidence before execution starts
6. Re-read the plan before major decisions
7. Update `progress.md` after meaningful work
8. Update phase status in `task_plan.md`
9. Log errors instead of retrying the same failed action silently

## Rules

### Create plan first

Do not start a complex task without a plan.

### Read before deciding

Before major changes or direction shifts, read the active `task_plan.md`.

### Validate before executing

For ambiguous, cross-stack, or high-risk work, record:

- locked decisions
- validation evidence from code, docs, tests, or runtime checks
- exit criteria for the current phase or story

Do not begin implementation until those items are clear enough to execute without guessing.

### Close cleanly

Before considering the task complete, make sure:

- the current phase outcome is clear
- validation run or validation gaps are recorded
- docs or contracts changed by the work are updated or explicitly called out

### Update after acting

After completing a phase or meaningful chunk of work:

- update `progress.md`
- update phase status
- record files changed

### Log failures

If an action fails:

- record the failure
- change approach on the next attempt
- do not repeat the exact same failed action blindly

## Templates

- [templates/task_plan.md](templates/task_plan.md)
- [templates/findings.md](templates/findings.md)
- [templates/progress.md](templates/progress.md)

## Scripts

- `scripts/init-session.sh` initializes planning files
- `scripts/resolve-plan-dir.sh` resolves the active plan directory
- `scripts/set-active-plan.sh` switches active plan
- `scripts/attest-plan.sh` stores a checksum for the current plan
- `scripts/session-catchup.py` summarizes current planning state on resume

## References

- [references/reference.md](references/reference.md)
- [references/examples.md](references/examples.md)
