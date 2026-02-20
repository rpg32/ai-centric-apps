# Bugfix

Fast-path a correction through the relevant pipeline stages with lightweight gates. Use this for small, well-understood fixes where the user already knows what's wrong and which stage to fix it in.

## Usage

```
/bugfix {description}
```

- `description` -- Brief description of the fix (e.g., "fix agent tool selection error", "correct RAG chunking config", "fix context window rendering bug")

## Workflow

### Step 1: Verify Project Context
Read project registry and state.

### Step 2: Identify Target Stage
Ask user which stage the fix belongs to, or infer from description.

If the fix spans multiple stages, suggest using `/feature` instead.

### Step 3: Enter Quick Fix Mode
Update project-state.json to mark target stage for quick fix.

### Step 4: Execute Fix
Tell user to run the stage command. Quick fix gate behavior: FAIL blocks, WARN does not block.

### Step 5: Complete
After gate review passes, restore stage status, update work unit.

## Error Handling
- No active project -> list available projects
- No description provided -> ask
- Fix spans multiple stages -> suggest `/feature`
- Gate review fails -> normal failure handling
