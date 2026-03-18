# AGENTS.md

This file defines how AI agents should behave in this repository.
Read this file at the start of every session before touching any code.

---

## Repository Layout

```
.
├── AGENTS.md              ← You are here
├── CHANGELOG.md
├── cliff.toml
├── docs/
│   ├── ARCHITECTURE.md    ← System design overview
│   ├── CONSTRAINTS.md     ← Hard constraints to respect
│   ├── DECISIONS.md       ← Architecture decision records (ADR)
│   └── README.md
├── app/                   ← Application source
├── firmware/              ← Firmware source
├── web/                   ← Web frontend source
└── tasks/
    ├── todo.md            ← Active task plan with checkboxes
    ├── session.md         ← Current session context
    ├── review.md          ← Post-task review notes
    ├── lessons.md         ← Accumulated lessons from corrections
    ├── knowledge.md       ← Domain knowledge reference
    └── debug.md           ← Hypotheses when stuck (never guess)
```

---

## Session Start Checklist

Before doing anything else, read these files in order:

1. `tasks/lessons.md` — apply every rule listed there
2. `tasks/todo.md` — understand current task state
3. `docs/CONSTRAINTS.md` — know what you must not break
4. `tasks/session.md` — pick up context from last session

---

## Daily Loop

Execute this loop every session, one item at a time:

1. **Pick** the first `[ ]` item in `tasks/todo.md`
2. **Mark `[/]`** — signal that work has started
3. **Plan** — for any task with 3+ steps, write the plan inline in `tasks/todo.md` before writing code, get confirmation
4. **Implement** — one item, minimal scope
5. **Verify** — run tests, check logs, confirm behaviour matches expected
6. **Mark `[x]`** — only after verification passes
7. **Update** `tasks/review.md` — add a short entry for what was done
8. **Capture** — mistake corrected → `tasks/lessons.md` immediately; new fact learned → `tasks/knowledge.md`
9. **Repeat from step 1** until no `[ ]` items remain
10. **End session** — update `tasks/session.md` so the next session starts instantly

---

## Workflow Orchestration

### 1. Plan-First Default

- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- Write the plan to `tasks/todo.md` as checkable items before touching code
- Get confirmation before starting implementation
- Use plan mode for verification steps, not just building
- If something goes sideways mid-task: **STOP**, update `tasks/todo.md`, re-plan

### 2. Subagent Strategy

- Use subagents liberally to keep the main context window clean
- Offload research, exploration, and parallel analysis to subagents
- One task per subagent — focused execution, no scope creep
- For complex problems, throw more compute at it via subagents rather than expanding the main context
- Subagent results that are worth keeping go into `tasks/knowledge.md`

### 3. Self-Improvement Loop

- After **any** correction from the user: update `tasks/lessons.md` immediately
- Write the lesson as a concrete rule, not a vague note
- Ruthlessly iterate on lessons until the mistake rate drops
- Review `tasks/lessons.md` at the start of every session

### 4. Verification Before Done

- Never mark a task complete without proving it works
- Diff behaviour between main and your changes when relevant
- Ask yourself: *"Would a staff engineer approve this?"*
- Run tests, check logs, demonstrate correctness — then check the box

### 5. Demand Elegance (Balanced)

- For non-trivial changes: pause and ask *"Is there a more elegant way?"*
- If a fix feels hacky: step back and implement the clean solution
- Skip this for simple, obvious fixes — do not over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing

- When given a bug report: just fix it — no hand-holding required
- Point at logs, errors, and failing tests, then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

---

## Task Management

### Checkbox States

Work **one item at a time**. Never start the next item before the current one is verified.

```
[ ]  not started
[/]  in progress  ← mark this when you begin
[x]  complete     ← mark this only after verification passes
[-]  skipped / won't do (add reason inline)
```

### When Stuck

Do **not** guess. Do not try random fixes hoping one works.

1. Stop immediately
2. Write a structured hypothesis in `tasks/debug.md`:
   - What you expected to happen
   - What actually happened
   - Possible causes (ranked by likelihood)
   - Next experiment to isolate the cause
3. Run the experiment, record the result
4. Repeat until root cause is confirmed, then fix
5. If the root cause is worth remembering, move it to `tasks/knowledge.md`
6. Clear the debug entry

### Knowledge Capture

If you discover a new fact about the domain, system behaviour, or codebase that is not already documented — add it to `tasks/knowledge.md` immediately. Do not let useful context disappear at the end of a session.

### Escalation to User

Ask the user when:
- The plan has an architectural decision with multiple valid options
- A constraint in `docs/CONSTRAINTS.md` conflicts with the task requirements
- A bug cannot be reproduced after completing the full debug protocol

Do not ask the user for:
- Step-by-step implementation guidance
- Debugging help before attempting the debug protocol
- Confirmation of obvious next steps

---

## Core Principles

**Simplicity First**
Make every change as simple as possible. Touch minimal code. Prefer boring solutions.

**No Laziness**
Find root causes. No temporary fixes. No TODO comments left behind. Senior developer standards.

**Minimal Impact**
Changes should only touch what is necessary. Avoid introducing bugs in unrelated areas.

**Respect Constraints**
Always check `docs/CONSTRAINTS.md` before proposing a solution. Hard constraints are non-negotiable.

**Respect Architecture**
Read `docs/ARCHITECTURE.md` and `docs/DECISIONS.md` before making structural changes. Propose an ADR when introducing a new architectural decision.

---

## File Reference

| File | When to write | Who |
|------|--------------|-----|
| `tasks/todo.md` | Before starting (plan), during (progress), after (done) | Agent + user |
| `tasks/session.md` | End of every session | Agent |
| `tasks/lessons.md` | Immediately after any correction | Agent only |
| `tasks/knowledge.md` | When a new non-obvious fact is discovered | Agent + user |
| `tasks/debug.md` | When stuck — never before; clear after resolved | Agent only |
| `tasks/review.md` | After each completed task | Agent |
| `docs/DECISIONS.md` | When introducing a new architectural decision | Agent proposes, user approves |

---

## What Not To Do

- Do not start implementation before the plan is confirmed
- Do not mark tasks complete without verification
- Do not skip updating `tasks/lessons.md` after a correction
- Do not make sweeping changes outside the task scope
- Do not ignore `docs/CONSTRAINTS.md`
- Do not guess when stuck — write a hypothesis in `tasks/debug.md` first
- Do not let a useful discovery vanish — add it to `tasks/knowledge.md`
- Do not work on multiple todo items simultaneously
- Do not ask the user for guidance before attempting the debug protocol
