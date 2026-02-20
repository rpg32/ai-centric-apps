# Feature

Start a new scoped work unit in the active AI-Centric Apps project. Analyzes which pipeline stages are affected, creates a targeted work plan, and walks through only the relevant stages.

## Usage

```
/feature {name}
```

- `name` -- Short descriptive name for the work unit (e.g., "add-oauth-login", "multi-agent-routing", "rag-pipeline-v2")

## Workflow

### Step 1: Verify Project Context
Verify active project and that initial pipeline is complete.

### Step 2: Define Scope
Present pipeline stages and ask user to describe the work. Analyze which stages are affected, unaffected, or review-only.

### Step 3: Register Work Unit
Add work unit to `project-state.json` with affected stages.

### Step 4: Prepare Stage Re-Entry
Update affected stage statuses to `"evolution"` with `evolution_context`.

### Step 5: Git Commit
Commit in PROJECT repo.

### Step 6: Begin First Stage
Tell user which stage to run first. Do NOT auto-start.

### Step 7: Complete (when invoked with "complete" argument)
If invoked as `/feature complete`: verify all affected stages passed gates, generate summary, update work unit status.

## Error Handling
- No active project -> list available projects
- Project hasn't completed initial pipeline -> warn but allow override
- Work unit name already exists -> append number
- Another work unit active -> allow concurrent, warn if scopes overlap
