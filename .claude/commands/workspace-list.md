# List Workspaces

Show all active git worktrees for this AI-Centric Apps system.

## Workflow

### 1. List Worktrees
Run: `git worktree list`

### 2. Display Results

For each worktree, show:

| Path | Branch | Status |
|------|--------|--------|
| {path} | {branch} | {clean/dirty} |

The main worktree is marked as (main).

### 3. Guidance
- If worktrees exist: remind user they can close them with `/workspace-close {name}`
- If no extra worktrees: inform user all work is on the main branch
