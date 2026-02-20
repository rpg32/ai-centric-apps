# Create New Project

Create a new AI-Centric Apps project and initialize it for pipeline execution.

## Workflow

### 1. Gather Project Information
Ask the user for:
- **Project name**: A short descriptive name (will be slugified for directory name)
- **Description**: What this project aims to achieve
- **Requirements**: Key requirements, constraints, or specifications

### 2. Generate Project ID
Create a slug from the project name: lowercase, hyphens for spaces, no special characters.
Example: "AI Code Reviewer" -> "ai-code-reviewer"

### 3. Stamp Project from Template
Copy `project-template/` to `projects/{project-id}/`:
- Replace `{{PROJECT_ID}}` with the generated ID
- Replace `{{PROJECT_NAME}}` with the user's project name
- Replace `{{PROJECT_DESCRIPTION}}` with the description
- Replace `{{PROJECT_REQUIREMENTS}}` with the requirements
- Replace `{{CREATED_DATE}}` with current date (YYYY-MM-DD)
- Replace `{{SYSTEM_ID}}` with `ai-centric-apps`
- Replace `{{SYSTEM_NAME}}` with `AI-Centric Apps`
- Generate `{{STAGES_CHECKLIST}}` from pipeline stages as markdown checkboxes
- Generate `{{STAGES_DIRECTORIES}}` as a directory listing
- Generate `{{STAGES_PIPELINE}}` as JSON object with stage statuses
- Set `{{FIRST_STAGE_ID}}` to `01-scoping`

### 4. Create Stage Directories
Create numbered stage directories in the project:
- `projects/{project-id}/01-scoping/`
- `projects/{project-id}/02-agent-architecture/`
- `projects/{project-id}/03-context-design/`
- `projects/{project-id}/04-ai-integration/`
- `projects/{project-id}/05-implementation/`
- `projects/{project-id}/06-evaluation/`
- `projects/{project-id}/07-deployment/`

### 5. Initialize Git Repository
```
cd projects/{project-id}
git init
git add -A
git commit -m "Initialize project: {project-name}"
```

### 6. Register Project
Add entry to `projects/registry.json`:
```json
{
  "id": "{project-id}",
  "name": "{project-name}",
  "created": "{date}",
  "current_stage": "01-scoping",
  "status": "active"
}
```
Commit registry change in the SYSTEM repo: `git add projects/registry.json && git commit -m "Register project: {project-id}"`

### 7. Welcome and Next Steps
Display:
- Project created at: `projects/{project-id}/`
- Current stage: Domain and Intent Scoping
- Suggest running `/stage-01-scoping` to begin the pipeline

## Error Handling
- If project ID already exists in registry -> ask for different name
- If directory already exists -> warn and ask to proceed or rename
- If git init fails -> report error, project is still usable without git
