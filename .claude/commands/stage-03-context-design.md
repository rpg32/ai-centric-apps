# Pipeline Stage: Context Interface Design

Execute stage **03-context-design -- Context Interface Design** of the AI-Centric Apps pipeline.

## Pre-Checks

1. **Verify active project**: Read `projects/registry.json` to identify the active project. If ambiguous, ask the user.
2. **Verify correct stage**: Read `projects/{project-id}/project-state.json`. Confirm `current_stage` matches `03-context-design`.
3. **Detect evolution mode**: Check if stage `03-context-design` has `status: "evolution"` or `status: "quick-fix"`.
4. **Check for blocking issues**: Review `issues` array.
5. **Check inbox**: Scan `comms/inbox/` for pending messages.
6. **Check for existing partial work**: Scan `projects/{project-id}/03-context-design/`.

## Dispatch

Delegate this stage to the **context-design-agent** subagent with:

- **Project**: {project-id} at projects/{project-id}/
- **Working directory**: projects/{project-id}/03-context-design/
- **Stage**: 03-context-design (Context Interface Design)

Also provide outputs from previous stages:
- `01-scoping/user-goal-map.md`
- `01-scoping/tech-stack-decision.json`
- `02-agent-architecture/agent-architecture.md`
- `02-agent-architecture/tool-schemas.json`

## Post-Dispatch

1. **Verify artifacts**: context-interface-spec.md, interaction-patterns.md, context-tool-inventory.md, gate-review.md
2. **Update project state**: Set stage status to "review_pending"
3. **Git commit** in PROJECT repo
4. **Learning capture**: Check for issues-log.md / successes-log.md
5. **Recommend `/clear`**

---

## Evolution Mode

Same protocol as stage-01. See `/stage-01-scoping` for full evolution mode documentation.

## Error Handling
- If subagent not found -> report error
- If previous stage outputs are missing -> warn user, suggest completing prior stages
