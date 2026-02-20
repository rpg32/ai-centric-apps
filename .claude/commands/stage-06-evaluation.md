# Pipeline Stage: Agent Evaluation and Testing

Execute stage **06-evaluation -- Agent Evaluation and Testing** of the AI-Centric Apps pipeline.

## Pre-Checks

1. **Verify active project**: Read `projects/registry.json` to identify the active project. If ambiguous, ask the user.
2. **Verify correct stage**: Read `projects/{project-id}/project-state.json`. Confirm `current_stage` matches `06-evaluation`.
3. **Detect evolution mode**: Check if stage `06-evaluation` has `status: "evolution"` or `status: "quick-fix"`.
4. **Check for blocking issues**: Review `issues` array.
5. **Check inbox**: Scan `comms/inbox/` for pending messages.
6. **Check for existing partial work**: Scan `projects/{project-id}/06-evaluation/`.

## Dispatch

Delegate this stage to the **evaluation-agent** subagent with:

- **Project**: {project-id} at projects/{project-id}/
- **Working directory**: projects/{project-id}/06-evaluation/
- **Stage**: 06-evaluation (Agent Evaluation and Testing)

Also provide outputs from previous stages:
- `01-scoping/capability-spec.md`
- `01-scoping/user-goal-map.md`
- `02-agent-architecture/agent-architecture.md`
- `02-agent-architecture/tool-schemas.json`
- `02-agent-architecture/security-architecture.md`
- `03-context-design/context-tool-inventory.md`
- `04-ai-integration/agent-config-package.json`
- `04-ai-integration/prompt-library.md`
- `05-implementation/src/`
- `05-implementation/test-suite.md`

## Post-Dispatch

1. **Verify artifacts**: evaluation-report.md, benchmark-results.json, security-audit.md, gate-review.md
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
