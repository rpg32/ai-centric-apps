# Export Project

Export an AI-Centric Apps project as a portable archive for sharing, backup, or transfer to another system instance.

## Usage

```
/project-export {project-id} [--with-history] [--portable]
```

- `project-id`: The project to export (as registered in `projects/registry.json`)
- Flags (optional, combinable):
  - `--with-history`: Include full git history (`.git/` directory). Default: current state only.
  - `--portable`: Add `SETUP.md`, verify all paths are relative, make fully self-contained.

## Workflow

1. Identify project from registry
2. Verify project exists and has project-state.json
3. Check git status for uncommitted changes
4. Generate export-manifest.json
5. Package export to `exports/{project-id}-{YYYY-MM-DD}/`
6. Apply portable mode if --portable
7. Report results

## Error Handling

| Condition | Response |
|-----------|----------|
| Project not found in registry | List all available projects with IDs |
| Dirty git and user does not confirm | Stop. Do not export. |
| Export directory already exists for today | Ask: overwrite, append date suffix, or cancel |
