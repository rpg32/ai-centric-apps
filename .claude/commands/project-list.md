# List Projects

List all AI-Centric Apps projects from the registry.

## Workflow

### 1. Read Registry
Read `projects/registry.json`.

### 2. Display Project List

For each project, show:

| ID | Name | Stage | Status |
|----|------|-------|--------|
| {id} | {name} | {current_stage} | {status} |

### 3. Summary
- Total projects: {count}
- Active: {count}
- Completed: {count}

If no projects exist, suggest running `/project-new`.
