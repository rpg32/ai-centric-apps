# Import Existing Project

Import an existing codebase into this AI-Centric Apps expert system. Performs a comprehensive evaluation of the project against the system's pipeline, then brings it under management.

## Usage

```
/project-import {source-path}
```

- `source-path`: Path to the existing project directory (absolute or relative to system root)

## Agent Loading

Read these skills before executing:
- `.claude/CLAUDE.md` -- System orchestrator for pipeline awareness
- All `.claude/skills/*/SKILL.md` files -- Needed to evaluate project against domain expertise
- All `.claude/agents/*.md` files -- Needed to understand what each pipeline stage expects

## Workflow

### 1. Validate Source Path

Verify the source path exists and is a directory containing project files.

### 2. Scope Analysis

Examine the project to understand its full scope: type, tech stack, goals, size.

### 3. System Fit Check

**[DECISION POINT]** -- Evaluate whether this project matches the AI-Centric Apps domain (agent-first architecture, AI-centric application design).

### 4. Current State Assessment

Examine code quality, build system, dependencies, tests, documentation, configuration.

### 5. Pipeline Comparison -- Ideal vs Actual

For each of the 7 pipeline stages, compare what the pipeline would produce against what currently exists:
- 01-scoping: capability-spec.md, user-goal-map.md, domain-context-inventory.md, tech-stack-decision.json
- 02-agent-architecture: agent-architecture.md, tool-schemas.json, rag-source-plan.md, model-selection.md, security-architecture.md
- 03-context-design: context-interface-spec.md, interaction-patterns.md, context-tool-inventory.md
- 04-ai-integration: platform-config.json, prompt-library.md, rag-config.json, tool-definitions.json, agent-config-package.json
- 05-implementation: src/, data-model.md, database-schema.sql, test-suite.md
- 06-evaluation: evaluation-report.md, benchmark-results.json, security-audit.md
- 07-deployment: deployment-config.md, ci-cd-pipeline.yml, api-spec.yaml, user-docs.md

### 6-8. Gap Analysis, Problem Detection, Improvement Suggestions

Aggregate findings into gap analysis, problem report, and improvement/feature suggestions.

### 9. Present Full Evaluation Report

**[DECISION POINT]** -- Ask user: Import as-is, Import and remediate, or Cancel.

### 10. Execute Import

Copy project, create stage directories, generate project-state.json, save evaluation report, initialize git repo, register project.

Stage directories to create:
- `projects/{project-id}/01-scoping/`
- `projects/{project-id}/02-agent-architecture/`
- `projects/{project-id}/03-context-design/`
- `projects/{project-id}/04-ai-integration/`
- `projects/{project-id}/05-implementation/`
- `projects/{project-id}/06-evaluation/`
- `projects/{project-id}/07-deployment/`

## Error Handling

See the full error handling table in the scaffold template documentation.
