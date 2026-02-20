# Close Workspace

Remove a workspace's worktree directory and deactivate it. Optionally merge its branch to main. Can be called from within the worktree or from the main system directory.

## Usage
`/workspace-close {name}`

## Workflow

### 1. Detect Current Location and Identify Workspace
Check if inside a worktree or main system directory.

### 2. Detect Branch State
Check current branch of the worktree.

### 3. Check for Uncommitted Changes
If uncommitted changes exist, offer: Commit, Stash, or Discard.

### 4. Ask What to Do with the Branch
Options: Merge to main, Keep branch, Delete branch.

### 5. Determine if Closing from Inside the Worktree
On Windows, the directory may be locked.

### 6. Execute the Chosen Action
Merge, keep, or delete the branch as requested.

### 7. Remove Worktree Directory (if not closing from inside)

### 8. Check for Other Sessions Using This Workspace

### 9. Clean Up Workspace State
Delete `.system-workspace-active.json` and update session env.

### 10. Report

## Error Handling
- No name provided (from main) -> list available workspaces
- Merge conflicts -> show conflicts, ask for resolution per file
- Uncommitted changes -> warn and offer options
