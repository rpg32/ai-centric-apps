# Start Workflow

Enter a named workflow in the AI-Centric Apps system.

## Arguments
- `{workflow-name}` — The ID of the workflow to enter (e.g., `pipeline`, `spike`, `review`)

## Workflow

### 1. Validate Workflow Name
Check that the provided workflow name matches a known workflow ID. If not, show available workflows and ask the user to choose.

### 2. Check Prerequisites

**Project requirement:**
- If the workflow has `requires_project: true`, verify an active project exists in `projects/registry.json`.
- If no project exists, suggest: "This workflow requires a project. Run `/project-new` first."

**Active workflow check:**
- Read the active project's `project-state.json` (if project exists) and check `active_workflow`.
- If another stateful workflow (`tracks_state: true`) is already active, warn: "Workflow '{name}' is already active. Run `/workflow-exit` first, or continue in the current workflow."
- Non-stateful workflows can always be started.

**Workflow-specific conditions:**
- For `review`: verify the project has at least one stage with status "completed".

### 3. Activate Workflow

If the workflow has `tracks_state: true` and a project is active:
- Update `project-state.json` field `active_workflow`:
  ```json
  {
    "id": "{workflow-id}",
    "name": "{workflow-name}",
    "started": "{YYYY-MM-DD}"
  }
  ```
- Add a history entry: `"action": "workflow_started", "details": "Entered {workflow-name} workflow"`
- Commit in the project repo: `git add project-state.json && git commit -m "Workflow: start {workflow-name}"`

### 4. Display Workflow Context

Show:
- Workflow name and description
- Available commands within this workflow
- Suggested next step:
  - For `pipeline`: Show current stage and suggest the stage command
  - For `spike`: "All agents are available. Start exploring."
  - For `review`: "Run `/design-review` or `/process-review` to begin."
  - For custom workflows: Show the workflow description and relevant commands

## Error Handling
- Unknown workflow name → list available workflows
- Missing project for project-required workflow → suggest `/project-new`
- Active stateful workflow → suggest `/workflow-exit` first
