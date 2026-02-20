# Create Workspace

Create a git worktree for parallel work on this AI-Centric Apps system.

## Usage
`/workspace-create {name}`

## Workflow

### 1. Validate Name
- Name must be provided as argument
- Sanitize: lowercase, alphanumeric and hyphens only
- Check that branch `ws/{name}` doesn't already exist

### 2. Check for Conflicts
Verify branch and worktree directory don't already exist.

### 3. Create Worktree
```bash
git -C "$SYSTEM_ROOT" worktree add "$SYSTEM_ROOT/../ai-centric-apps-ws-{name}" -b "ws/{name}"
```

### 4. Persist Workspace State
Write `.system-workspace-active.json` at `$SYSTEM_ROOT`.

### 5. Update Session Env Immediately
Write current session's env file so env vars take effect immediately.

### 6. Report to User
```
Workspace created and activated.
  Branch:    ws/{name}
  Path:      {absolute-path-to-worktree}
When done, run: /workspace-close {name}
```

## Error Handling
- If no name provided -> ask for one
- If branch already exists -> suggest a different name
- If worktree creation fails -> show git error
