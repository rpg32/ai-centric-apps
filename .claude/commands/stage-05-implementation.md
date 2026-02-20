# Pipeline Stage: Application Implementation

Execute stage **05-implementation -- Application Implementation** of the AI-Centric Apps pipeline.

## Pre-Checks

1. **Verify active project**: Read `projects/registry.json` to identify the active project. If ambiguous, ask the user.
2. **Verify correct stage**: Read `projects/{project-id}/project-state.json`. Confirm `current_stage` matches `05-implementation`.
3. **Detect evolution mode**: Check if stage `05-implementation` has `status: "evolution"` or `status: "quick-fix"`.
4. **Check for blocking issues**: Review `issues` array.
5. **Check inbox**: Scan `comms/inbox/` for pending messages.
6. **Check for existing partial work**: Scan `projects/{project-id}/05-implementation/`.

## Dispatch

Delegate this stage to the **implementation-agent** subagent with:

- **Project**: {project-id} at projects/{project-id}/
- **Working directory**: projects/{project-id}/05-implementation/
- **Stage**: 05-implementation (Application Implementation)

Also provide outputs from previous stages:
- `01-scoping/tech-stack-decision.json`
- `01-scoping/capability-spec.md`
- `02-agent-architecture/agent-architecture.md`
- `02-agent-architecture/security-architecture.md`
- `03-context-design/context-interface-spec.md`
- `03-context-design/interaction-patterns.md`
- `03-context-design/context-tool-inventory.md`
- `04-ai-integration/platform-config.json`
- `04-ai-integration/prompt-library.md`
- `04-ai-integration/rag-config.json`
- `04-ai-integration/tool-definitions.json`
- `04-ai-integration/agent-config-package.json`

**Checkpoint protocol**: Checkpoint after src/ scaffolding and data layer before integrating the AI platform layer.

## Post-Dispatch

1. **Verify artifacts**: src/, data-model.md, database-schema.sql, test-suite.md, gate-review.md
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
