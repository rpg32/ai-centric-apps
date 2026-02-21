# Quickstart

Guided first-time walkthrough for new users of the AI-Centric Apps system. Explains the system structure, shows available commands and workflows, and offers to create a first project.

## Usage

```
/quickstart
```

No arguments. This is an interactive guided experience.

## Agent Loading

No specialist agent needed. This command runs directly in the orchestrator context. It reads files and explains structure — no subagent dispatch required.

## Workflow

### Step 1: Check Current State

Read `projects/registry.json` from the system root.

Count the number of registered projects and their statuses.

**If projects already exist:**

> "Welcome back! You have {N} project(s) registered:"
> {list each project with ID, name, and status}
>
> "Since you already have projects, you may not need the full walkthrough. Would you like to:"
> 1. **Continue anyway** — Walk through the system structure as a refresher
> 2. **Create a new project** — Jump straight to `/project-new`
> 3. **Open an existing project** — I'll show you how

If the user picks 2, tell them to run `/project-new` and stop.
If the user picks 3, show the project list and explain: "Run `/project-open {project-id}` to activate a project, then use pipeline or evolution commands to work on it." Stop.
If the user picks 1, continue to Step 2.

**If no projects exist (or registry is empty):**

> "Welcome to the AI-Centric Apps system! This is your first time here — let me walk you through how everything works, then we'll create your first project."

Continue to Step 2.

### Step 2: Explain What This System Is

Present:

> **What is this system?**
>
> The AI-Centric Apps system is a domain-specific expert system for designing and building software applications where AI agents and large language models are the foundational architecture. It contains specialized agents, domain knowledge, tool integrations, and a quality-gated pipeline — all tuned for this domain.
>
> Think of it this way:
> - **This system** is a factory — it knows how to build and manage AI-centric application projects
> - **Projects** are what the factory produces — each one lives in `projects/{project-id}/` with its own git repo
> - **Consultation mode** is always available — ask domain questions anytime without creating a project
>
> The system was built by The Forge, but it runs completely on its own.

### Step 3: Show Directory Structure

Present:

> **What's here?**
>
> ```
> ai-centric-apps/
> ├── .claude/commands/     <- Slash commands you can type (like /quickstart)
> ├── .claude/agents/       <- Specialist agents for each pipeline stage
> ├── .claude/skills/       <- Domain knowledge and tool expertise
> ├── projects/             <- Where your projects live
> │   └── registry.json     <- Master list of all projects
> ├── templates/            <- Output templates for domain artifacts
> ├── comms/                <- Cross-system communication infrastructure
> ├── references/           <- Reference material (books, papers, etc.)
> └── tool-stack.json       <- Required tools and their configurations
> ```

### Step 4: Show Available Commands

Present:

> **What can you do from here?**
>
> **Project Management:**
>
> | Command | What it does |
> |---------|-------------|
> | `/project-new` | Create a new project (the main starting point) |
> | `/project-list` | See all your registered projects |
> | `/project-open {id}` | Activate a project for work |
> | `/project-status` | Check current project state |
> | `/project-import` | Bring in an existing codebase |
> | `/project-export` | Package a project for sharing |
>
> **Workflows:**
>
> | Command | What it does |
> |---------|-------------|
> | `/workflow-list` | See available workflows and current state |
> | `/workflow-start {name}` | Enter a named workflow (e.g., pipeline, spike, review) |
> | `/workflow-status` | Check current workflow progress |
> | `/workflow-exit` | Return to consultation mode |
>
> **Evolution (after pipeline completes):**
>
> | Command | What it does |
> |---------|-------------|
> | `/feature {name}` | Scoped new work — analyzes affected stages |
> | `/bugfix {desc}` | Small correction through a single stage |
> | `/release {name}` | Tag a checkpoint and generate summary |
> | `/iteration` | Start a new iteration cycle |
>
> **Maintenance:**
>
> | Command | What it does |
> |---------|-------------|
> | `/env-check` | Verify all required tools are installed |
> | `/digest` | Feed reference material into system knowledge |
> | `/skill-update` | Improve a skill with new knowledge |
>
> The one you'll use most to get started is **`/project-new`** — it creates a project and enters the pipeline.

### Step 5: Explain the Pipeline

Present:

> **How does the pipeline work?**
>
> When you create a project and start the pipeline workflow, it goes through quality-gated stages. Each stage has a specialist agent with domain knowledge:
>
> | Stage | Name | Description |
> |-------|------|-------------|
> | 01 | Domain and Intent Scoping | Define capabilities, user goals, tech stack |
> | 02 | Agent Architecture Design | Design agents, tools, security, model selection |
> | 03 | Context Interface Design | Design context windows, interaction patterns |
> | 04 | AI Platform Integration | Configure providers, prompts, RAG, tool definitions |
> | 05 | Application Implementation | Build the application with TDD |
> | 06 | Agent Evaluation and Testing | Test accuracy, security, performance |
> | 07 | Deployment and Packaging | CI/CD, deployment, documentation |
>
> Each stage:
> 1. Runs a specialist agent with preloaded domain skills
> 2. Produces output artifacts in the project directory
> 3. Ends with a **gate review** — specific criteria that must pass before advancing
>
> Gate reviews are blocking. If a gate fails, the stage is reworked until it passes. This ensures quality at every step.
>
> **Tip:** Run `/clear` between stages to keep context fresh. All progress is saved to `project-state.json` — nothing is lost.

### Step 6: Explain Post-Pipeline Work

Present:

> **What happens after the pipeline?**
>
> Once all stages pass their gates, your project enters **evolution mode**. Instead of re-running the full pipeline, you use targeted commands:
>
> - **`/feature`** — For new features or scoped changes. The system analyzes which stages are affected and walks through only those.
> - **`/bugfix`** — For small, well-understood corrections. Fast-pathed through a single stage.
> - **`/release`** — Tag a release point and generate a summary of work since the last milestone.
> - **`/iteration`** — Reopen multiple stages for a broad improvement pass.
>
> You can also always ask questions in **consultation mode** — no workflow needed. All agents and skills are available for advice, analysis, and domain questions.

### Step 7: Offer to Create First Project

Ask the user:

> "Ready to create your first project?"
>
> 1. **Yes, let's go** — I'll help you start with `/project-new`
> 2. **Check environment first** — Run `/env-check` to verify all tools are installed
> 3. **Not yet** — I want to explore more first
> 4. **I have questions** — Ask me anything about how this system works

**If yes:** Tell the user to run `/project-new` (or ask them what they want to build and pass it along as context). Do not auto-invoke `/project-new` — let the user trigger it explicitly.

**If env-check:** Tell the user to run `/env-check`. After that completes, suggest `/project-new` as the next step.

**If not yet:** Point them to resources:
> "No problem. Here are some things to explore:"
> - Run `/workflow-list` to see available workflows
> - Check `references/` for any domain reference material
> - Ask me domain questions in consultation mode — no project needed
>
> "When you're ready, run `/project-new` to begin."

**If questions:** Answer their questions using your knowledge of the system (from CLAUDE.md and loaded skills). Stay in the quickstart conversation — don't redirect to other commands unless the question is specifically about running one.

## Error Handling

| Condition | Response |
|-----------|----------|
| `projects/registry.json` missing | Create it with `{"projects": []}`. Note: "Registry was empty — created a fresh one." Continue normally. |
| Not in system root directory | Check for `.claude/agents/` or `tool-stack.json`. If missing: "This command should be run from the system root directory." |
| User asks to skip the walkthrough | Respect their preference. Point to `/project-new` directly. |

## Git Commit

No git commits. This command is read-only — it explains structure and offers guidance. No files are created or modified.
