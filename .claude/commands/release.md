# Release

Tag a project milestone, generate a summary of work since the last milestone (or project creation), and update project state. This is a checkpoint -- it doesn't modify any artifacts, it records where the project stands.

## Usage

```
/release {name}
```

- `name` -- Milestone identifier (e.g., "v1.0", "alpha-release", "mvp", "beta")

## Workflow

### Step 1: Verify Project Context
Check for active work units (warn if any exist).

### Step 2: Gather Milestone Data
Find previous milestone, collect changes since then (work units, quick fixes, stage re-entries, issues resolved).

### Step 3: Generate Summary
Create `projects/{project-id}/milestones/{name}.md` with changes, pipeline status, and auto-generated summary.

### Step 4: Update Project State
Add milestone to `project-state.json` milestones array.

### Step 5: Git Commit and Tag
```
cd projects/{project-id}
git add -A
git commit -m "Milestone: {name}"
git tag "{name}" -m "Milestone: {name} -- {summary}"
```

## Error Handling
- Milestone name already exists -> suggest different name
- No changes since last milestone -> warn, allow anyway
- Active work units -> warn but allow override
