# List Agents

Display all specialist agents in this expert system with their roles, stages, and skill dependencies.

## Usage
```
/agent-list
```

No arguments. Read-only -- no files are modified.

## Workflow

1. Scan `.claude/agents/` for all agent files
2. Extract name, role, stage, knowledge skills, tool skills from each
3. Cross-reference with pipeline in `.claude/CLAUDE.md`
4. Display agent table with dependency details
5. Flag any warnings: unstaffed stages, unassigned agents, missing dependencies
