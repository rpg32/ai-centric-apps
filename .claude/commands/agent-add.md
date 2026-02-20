# Add Agent

Add a new specialist agent to this expert system. Creates the agent skill file, optional supporting knowledge and tool skills, and wires the agent into the pipeline.

## Usage
```
/agent-add [stage-id] [agent-name]
```

## Workflow

1. Gather agent information (stage, name)
2. Define agent role, boundaries, expertise, tools
3. Check for existing relevant skills
4. Create agent file in `.claude/agents/`
5. Create supporting skills if needed
6. Wire into pipeline stage command
7. Confirm and commit in SYSTEM repo
