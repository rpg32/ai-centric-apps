# Pipeline Stage: Agent Architecture Design

Execute stage **02-agent-architecture -- Agent Architecture Design** of the AI-Centric Apps pipeline.

## Pre-Checks

1. **Verify active project**: Read `projects/registry.json` to identify the active project. If ambiguous, ask the user.
2. **Verify correct stage**: Read `projects/{project-id}/project-state.json`. Confirm `current_stage` matches `02-agent-architecture`. If not, warn appropriately.
3. **Detect evolution mode**: Check if stage `02-agent-architecture` has `status: "evolution"` or `status: "quick-fix"` in project-state.json.
4. **Check for blocking issues**: Review the `issues` array for any blocking items related to this stage.
5. **Check inbox**: Scan `comms/inbox/` for pending messages relevant to this stage.
6. **Check for existing partial work**: Scan `projects/{project-id}/02-agent-architecture/` for existing artifacts.

## Dispatch

Delegate this stage to the **architecture-agent** subagent with the following context:

- **Project**: {project-id} at projects/{project-id}/
- **Working directory**: projects/{project-id}/02-agent-architecture/
- **Stage**: 02-agent-architecture (Agent Architecture Design)
- **Evolution context**: {include evolution_context if detected, otherwise "Initial pipeline run"}
- **Existing artifacts**: {list files in 02-agent-architecture/ if any}

Also provide outputs from previous stages:
- `01-scoping/capability-spec.md`
- `01-scoping/user-goal-map.md`
- `01-scoping/domain-context-inventory.md`
- `01-scoping/tech-stack-decision.json`

**Checkpoint protocol**: Checkpoint after agent-architecture.md and tool-schemas.json before proceeding to RAG, model, and security artifacts.

## Post-Dispatch

1. **Verify artifacts**: agent-architecture.md, tool-schemas.json, rag-source-plan.md, model-selection.md, security-architecture.md, gate-review.md
2. **Update project state**: Set stage status to "review_pending"
3. **Git commit** in PROJECT repo
4. **Learning capture**: Check for issues-log.md / successes-log.md
5. **Recommend `/clear`**

---

## Evolution Mode

Same protocol as stage-01. See `/stage-01-scoping` for full evolution mode documentation.

## Error Handling
- If subagent not found -> report error
- If previous stage outputs are missing -> warn user, suggest completing 01-scoping first
- If evolution mode but stage directory is empty -> warn and run as initial execution
