# Remove Agent

Remove a specialist agent from this expert system. Performs impact analysis, cleans up files, optionally removes orphaned skill dependencies, and logs the removal reason.

## Usage
```
/agent-remove [agent-name]
```

## Workflow

1. Identify the agent
2. Impact analysis (stage commands, orphaned skills, cross-agent references)
3. Confirm with user and get reason
4. Remove files
5. Log removal to `agent-changes.log`
6. Commit in SYSTEM repo
