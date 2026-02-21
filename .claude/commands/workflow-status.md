# Workflow Status

Display the current workflow context and progress for the AI-Centric Apps system. Read-only — does not modify any files.

## Workflow

### 1. Determine Current State

Check for active project by reading `projects/registry.json`.

**If no active project:**
> Mode: **Consultation** (no project context)
> All agents and skills are available for questions and analysis.
> Run `/project-new` to create a project, or ask domain questions directly.

**If active project but no active workflow:**
Read `project-state.json`. Check `active_workflow` field (should be null).
> Mode: **Consultation** (project: {project-name})
> Current pipeline stage: {current_stage}
> Run `/workflow-start {name}` to enter a workflow, or ask domain questions directly.

**If active workflow:**
Read `project-state.json`. Display `active_workflow` details.
> Mode: **{workflow-name}** (project: {project-name})
> Started: {active_workflow.started}

Then show workflow-specific status:

### 2. Workflow-Specific Status

**Pipeline workflow:**
- Current stage: {current_stage}
- Stages completed: {count}/{total}
- Open issues: {count}
- Suggest next action (run stage command or gate review)

**Spike workflow:**
- Started: {date}
- No state tracking — just a reminder of what the user is exploring

**Review workflow:**
- Started: {date}
- Stages available for review: list completed stages

**Custom workflows:**
- Started: {date}
- Display any workflow-specific status fields

## Notes
- This is a read-only command. It does not modify project state.
- If `project-state.json` is missing or corrupt, report the error clearly.
