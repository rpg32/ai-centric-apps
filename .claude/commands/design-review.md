# Design Review

Cross-stage review of all completed stages in the active AI-Centric Apps project.

## Workflow

### 1. Load Project Context
- Read `projects/registry.json` to find active project
- Read `projects/{project-id}/project-state.json` to identify completed stages

### 2. Review Each Completed Stage
For each stage marked "completed":
1. Read the stage's key output artifacts
2. Read the stage's gate-review.md
3. Assess for consistency, completeness, quality, and forward-compatibility

### 3. Cross-Stage Checks
Look for contradictions, missing traceability, and potential downstream issues.

### 4. Generate Design Review Report
Create `projects/{project-id}/design-review.md`

### 5. Git Commit
In the PROJECT repo:
```
git add design-review.md
git commit -m "Design review: stages {first}-{last}"
```
