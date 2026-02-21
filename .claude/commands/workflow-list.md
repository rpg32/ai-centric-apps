# Workflow List

Display available workflows and current workflow state for the AI-Centric Apps system. Read-only — does not modify any files.

## Workflow

### 1. Determine Current State

Check for active project by reading `projects/registry.json`.
If a project is active, read its `project-state.json` and check the `active_workflow` field.

### 2. Display Available Workflows

Show this table of available workflows:

| Workflow | Description | Requires Project | Tracks State |
|----------|-------------|-----------------|--------------|
| pipeline | Execute the 7-stage AI-centric apps pipeline from scoping to deployment | Yes | Yes |
| spike | Free-form exploration and prototyping without pipeline constraints | No | No |
| review | Cross-stage design review and quality audit | Yes | No |

### 3. Display Current State

**If no active project:**
> Mode: **Consultation** (no project context)
> All agents and skills are available for questions and analysis.

**If active project but no active workflow:**
> Mode: **Consultation** (project: {project-name})
> All agents and skills are available. Run `/workflow-start {name}` to enter a workflow.

**If active workflow:**
> Mode: **{workflow-name}** (project: {project-name})
> Started: {date}
> {workflow-specific status info}
> Run `/workflow-exit` to return to consultation mode.

## Notes
- This is a read-only command. It does not modify project state.
- Consultation is the default state, not a workflow.
