# Iteration

Begin a new iteration cycle -- a broad pass through multiple pipeline stages to evolve the project. Unlike a feature (which targets specific stages for a specific change), an iteration reopens multiple stages for general improvement, refinement, or the next phase of work.

## Usage

```
/iteration [stage-list]
```

- No arguments -- reopen ALL stages for a full iteration cycle
- `stage-list` -- Comma-separated stage IDs to reopen (e.g., "02-agent-architecture,04-ai-integration,06-evaluation")

## Workflow

### Step 1: Verify project context and check for active work units.
### Step 2: Determine scope (full or partial iteration).
### Step 3: Tag current state as automatic pre-iteration milestone.
### Step 4: Reopen stages with evolution_context including iteration number.
### Step 5: Git commit in PROJECT repo.
### Step 6: Guide user through reopened stages in order.

### Automatic Completion
When the last reopened stage passes its gate review, the iteration closes automatically.

## Error Handling
- Project hasn't completed initial pipeline -> warn, allow override
- Another iteration already active -> warn, require completion first
- Invalid stage IDs -> list valid IDs
