# Open Project

Open an existing AI-Centric Apps project and display its current status.

## Workflow

### 1. Identify Project
If a project ID or name is provided as argument: use it.
If no argument: read `projects/registry.json` and list all projects with their status. Ask the user to select one.

### 2. Verify Project Exists
Check that `projects/{project-id}/project-state.json` exists. If not, report error.

### 3. Load Project State
Read `projects/{project-id}/project-state.json` and extract:
- Current pipeline stage
- Status of each completed/active stage
- Open issues
- Recent history entries

### 4. Display Dashboard

```
Project: {project-name}
Stage:   {current-stage-name}
Status:  {status}

Pipeline Progress:
  [x] 01-scoping: Domain and Intent Scoping
  [x] 02-agent-architecture: Agent Architecture Design
  [ ] 03-context-design: Context Interface Design
  [ ] 04-ai-integration: AI Platform Integration
  [ ] 05-implementation: Application Implementation
  [ ] 06-evaluation: Agent Evaluation and Testing
  [ ] 07-deployment: Deployment and Packaging

Open Issues: {count}
{issue summaries if any}

Recent Activity:
{last 3 history entries}
```

### 5. Suggest Next Action
Based on current stage and status, suggest:
- If stage is active -> run the stage command
- If gate review pending -> run `/gate-review`
- If issues exist -> address blocking issues first
- If project is completed -> congratulate and offer export options
