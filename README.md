# AI-Centric Apps

Designing and building software applications where AI agents and large language models are the foundational architecture -- not bolted on to existing software, but the core around which the entire application is constructed. The UI serves as a context facilitator mediating between users and AI agents, rather than providing traditional direct manipulation tools.

## Pipeline

This system follows a structured pipeline to take projects from concept to deliverable:

| # | Stage | Description |
|---|-------|-------------|
| 1 | Domain and Intent Scoping | Define agent capabilities, user goals, and technology stack |
| 2 | Agent Architecture Design | Design agent topology, tool schemas, RAG, security architecture |
| 3 | Context Interface Design | Design context windows, context tools, and interaction patterns |
| 4 | AI Platform Integration | Wire up LLM providers, build RAG pipeline, create prompt library |
| 5 | Application Implementation | Build frontend, backend, data layer, and test suite |
| 6 | Agent Evaluation and Testing | Test agent tool-calling, security, and end-to-end flows |
| 7 | Deployment and Packaging | Package, deploy, generate API docs and user docs |

Each stage has defined entry criteria, output artifacts, and a gate review that must pass before advancing.

## Getting Started

Open Claude Code in this directory. Available commands:

| Command | Description |
|---------|-------------|
| `/project-new` | Create a new project |
| `/project-open` | Open an existing project |
| `/project-list` | List all projects |
| `/project-status` | View current project status |
| `/gate-review` | Run gate review for current stage |
| `/design-review` | Cross-stage design review |
| `/workspace-create` | Create parallel worktree |
| `/workspace-list` | List active worktrees |
| `/workspace-close` | Merge worktree back |

## Tool Stack

### Essential
- anthropic SDK, openai SDK, pydantic, chromadb, FastAPI + uvicorn, promptfoo, pytest, ruff, docker, git, Python 3.10+, Node.js 18+

### Recommended
- litellm (provider abstraction), langgraph (multi-agent orchestration), langchain (RAG components), pydantic-ai (structured output), sentence-transformers (local embeddings), langfuse (observability), guardrails-ai (safety), playwright (e2e testing), vitest (TypeScript testing), eslint + prettier (TypeScript quality), sqlalchemy + alembic (Python ORM), uv (fast Python package manager), ollama (local LLM), Vercel AI SDK (TypeScript)

### MCP Servers
- chroma-mcp (ChromaDB vector operations)
- playwright-mcp (browser automation)
- promptfoo MCP (evaluation and red teaming)
- context7 (up-to-date library docs)
- @modelcontextprotocol/server-filesystem (file operations)

## Project Structure

Each project gets its own directory under `projects/` with its own git repository:

```
projects/
  registry.json             <- Tracks all projects
  my-project/               <- Own git repo
    project-state.json      <- Pipeline state, issues, metadata
    01-scoping/             <- Stage output directories
    02-agent-architecture/
    03-context-design/
    04-ai-integration/
    05-implementation/
    06-evaluation/
    07-deployment/
```

## Parallel Work

Multiple Claude Code instances can work simultaneously using git worktrees:

- `/workspace-create {name}` -- Create a worktree for parallel work
- `/workspace-list` -- Show active worktrees
- `/workspace-close {name}` -- Merge worktree and clean up
