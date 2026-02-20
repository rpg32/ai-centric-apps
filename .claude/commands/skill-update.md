# Update Skill

Improve an existing skill file with new knowledge, corrections, or better examples.

## Workflow

### 1. Identify Skill
If argument provided: use that skill path.
Otherwise: list all skill files across `.claude/agents/`, `.claude/skills/`, and `templates/` and ask which to update.

### 2. Read Current Skill
Read the skill file in full. Understand its structure, content, and gaps.

### 3. Gather Improvement
Ask the user what to improve:
- New information to add?
- Correction to existing content?
- Better examples or procedures?
- Additional failure modes?
- Updated tool commands?

### 4. Apply Changes
Edit the skill file. Preserve existing structure. Add new content in the appropriate sections. Do not remove working content unless explicitly replacing it.

### 5. Quality Check
Verify the updated skill:
- Still self-contained and loadable independently
- Quantitative rules have units
- No vague advice introduced
- File paths and tool references are accurate
- No domain content leaked into structural sections

### 6. Git Commit
In the SYSTEM repo:
```
git add {skill-path}
git commit -m "Skill update: {skill-name} -- {brief description}"
```
