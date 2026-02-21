# Environment Check

Verify that all required tools, packages, and prerequisites for this system are installed and properly configured. Reads `tool-stack.json` and checks each item.

## Usage

```
/env-check [--force]
```

- No arguments: Run checks, using cached results for items verified within the last hour.
- `--force`: Ignore cache and re-check everything.

## Workflow

### 1. Load Tool Stack

Read `tool-stack.json` from the system root (`$SYSTEM_ACTIVE_DIR/tool-stack.json`).

If the file does not exist:
> "No `tool-stack.json` found. This file is generated during system creation (Tool Scouting, Stage 3). Cannot verify environment without it."

Stop.

### 2. Load Cache (if not --force)

Read `.env-check-cache.json` from the system root. If it exists and `--force` was NOT specified, load previous results. Items checked less than 1 hour ago will be skipped and their cached status reused.

Cache format:
```json
{
  "last_run": "2026-02-19T14:30:00Z",
  "results": {
    "T01": { "status": "pass", "checked_at": "2026-02-19T14:30:00Z", "version": "8.0.1" },
    "T02": { "status": "fail", "checked_at": "2026-02-19T14:30:00Z", "error": "not found on PATH" }
  }
}
```

### 3. Check System Prerequisites

Iterate over `tool-stack.json → system_prerequisites[]`. For each prerequisite:

1. Run the appropriate check command based on platform:
   - **CLI tool**: `where {name}` (Windows) or `which {name}` (Unix), then `{name} --version`
   - **Python**: `python --version`
   - **Node.js**: `node --version`
   - **Git**: `git --version`

2. If a version constraint exists, compare installed version against required version.

3. Record result: PASS (installed, version OK), WARN (installed, version mismatch), or FAIL (not found).

### 4. Check Tools

Iterate over `tool-stack.json → tools[]`. For each tool, check based on its `type` field:

**CLI tools** (`type: "cli"`):
- Run `where {name}` or check the binary exists
- If `cli_commands` are listed, verify the primary command is callable
- Record installed version if detectable

**Python packages** (`type: "python"`):
- Run `python -c "import {package}; print({package}.__version__)"`
- If no `__version__` attribute, just check import succeeds: `python -c "import {package}"`

**MCP servers** (`type: "mcp"`):
- Check that the underlying command binary exists (e.g., if `installation.command` starts with `npx`, verify `npx` is on PATH)
- Check that the MCP server package is referenced in the system's `.claude/settings.json` or `.claude/settings.local.json` under `mcpServers`
- Do NOT attempt to start or connect to MCP servers — just verify the prerequisites are in place

**Other types** (installers, remote services):
- Check if the tool binary exists on PATH
- If `installation.method` is `"pre-installed"`, just verify the binary

### 5. Check Environment Variables

Iterate over `tool-stack.json → tools[]` and collect all `installation.env_vars` entries. For each environment variable:

1. Check if the variable is set in the current shell environment.
2. Record: PASS (set and non-empty), WARN (set but empty), or FAIL (not set).
3. Do NOT display the value — just confirm presence.

### 6. Check Python Requirements

If `tool-stack.json → python_requirements[]` is non-empty:

1. Run `python -c "import {module}"` for each requirement (strip version specifiers to get module name).
2. Record PASS or FAIL for each.

### 7. Display Results

Present a summary table:

```
## Environment Check Results

### System Prerequisites
| Prerequisite | Required | Installed | Status |
|-------------|----------|-----------|--------|
| Node.js     | >= 18.0  | 20.11.1   | PASS   |
| Python      | >= 3.10  | 3.12.1    | PASS   |
| Git         | any      | 2.43.0    | PASS   |

### Tools
| Tool | Type | Status | Details |
|------|------|--------|---------|
| KiCad | cli | PASS | v8.0.1 |
| pyspice | python | FAIL | Module not found |
| @anthropic/mcp-kicad | mcp | PASS | npx available, config present |

### Environment Variables
| Variable | Required By | Status |
|----------|------------|--------|
| KICAD_PATH | KiCad | PASS |
| OPENAI_API_KEY | llm-tool | FAIL |

### Python Packages
| Package | Status |
|---------|--------|
| numpy | PASS |
| pyspice | FAIL |

---

**Summary:** {pass_count} passed, {warn_count} warnings, {fail_count} failed
```

### 8. Show Install Commands for Failures

For each FAIL result, look up the corresponding `installation.command` from `tool-stack.json` and display it:

```
### How to Fix

**pyspice** (Python package):
  pip install PySpice

**OPENAI_API_KEY** (environment variable):
  Set this variable in your shell profile or .env file.
  Required by: llm-tool
```

If all checks pass:
> "All environment checks passed. Your system is ready."

### 9. Update Cache

Write results to `.env-check-cache.json` in the system root with the current timestamp.

## Error Handling

| Condition | Response |
|-----------|----------|
| `tool-stack.json` not found | Report error, stop. Suggest running system creation pipeline or checking the system root. |
| `tool-stack.json` malformed | Report parse error, show the problematic section, stop. |
| A check command hangs | Use a 10-second timeout per check. If exceeded, record as WARN with "check timed out". |
| Python not installed | Record as FAIL for the prerequisite. Skip all Python package checks. Report Python as the blocking issue. |
| Node.js not installed | Record as FAIL for the prerequisite. Mark all MCP server checks that depend on npx as FAIL. |
| Cache file corrupt | Delete cache, run all checks fresh. |
| No failures found | Congratulate and confirm readiness. |
| Running in a worktree | Use `$SYSTEM_ACTIVE_DIR` for all paths — this works in both main and worktree contexts. |

## Git Commit

No git commit. This command is read-only (except for the cache file, which is gitignored).

The `.env-check-cache.json` should be added to `.gitignore` if not already present.
