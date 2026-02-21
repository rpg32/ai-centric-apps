# Exit Workflow

Return to consultation mode in the AI-Centric Apps system.

## Workflow

### 1. Check Current State

Read the active project's `project-state.json` and check `active_workflow`.

**If no active workflow:**
> Already in consultation mode. No workflow to exit.
> (Do nothing, return early.)

### 2. Check for Unsaved State

If the workflow has `tracks_state: true`:
- Check if there are uncommitted changes in the project directory (`git status`)
- If uncommitted changes exist, warn: "There are uncommitted changes in the project. Consider committing before exiting the workflow."
- This is a warning only — do NOT block the exit.

### 3. Clear Active Workflow

Update `project-state.json`:
- Set `active_workflow` to `null`
- Add a history entry: `"action": "workflow_exited", "details": "Exited {workflow-name} workflow, returned to consultation mode"`

Commit in the project repo:
```
git add project-state.json
git commit -m "Workflow: exit {workflow-name}"
```

### 4. Confirm Return to Consultation

Display:
> Returned to **consultation mode** (project: {project-name}).
> All agents and skills are available. Run `/workflow-list` to see available workflows.

## Error Handling
- No active project → "No project context. Already in consultation mode."
- No active workflow → "Already in consultation mode."
- Git commit fails → Log warning, workflow is still exited (state change is more important than the commit)
