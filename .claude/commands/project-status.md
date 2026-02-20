# Project Status

Display the current status of the active AI-Centric Apps project. Read-only -- does not modify any files.

## Workflow

### 1. Identify Active Project
If argument provided: use that project ID.
Otherwise: check `projects/registry.json` for active projects. If multiple, list them and ask.

### 2. Load and Display

Read `projects/{project-id}/project-state.json` and display:

**Pipeline Progress:**
- `[ ]` or `[x]` 01-scoping: Domain and Intent Scoping
- `[ ]` or `[x]` 02-agent-architecture: Agent Architecture Design
- `[ ]` or `[x]` 03-context-design: Context Interface Design
- `[ ]` or `[x]` 04-ai-integration: AI Platform Integration
- `[ ]` or `[x]` 05-implementation: Application Implementation
- `[ ]` or `[x]` 06-evaluation: Agent Evaluation and Testing
- `[ ]` or `[x]` 07-deployment: Deployment and Packaging

**Open Issues:**
List all items from the `issues` array with severity and description.

**Deliverables:**
List any completed deliverables.

**Recent History:**
Show last 5 entries from the `history` array.

## Notes
- This is a read-only command. It does not modify project state.
- If project-state.json is missing or corrupt, report the error clearly.
