---
name: full-stack-architecture
description: Software architecture patterns for building the application layer around an agent core, including clean architecture, API design, database modeling, state management, and project scaffolding.
user-invocable: false
---

# Full-Stack Architecture for Agent-First Applications

## Purpose

Enable Claude to architect and implement the software layers that wrap around the AI agent core: backend API serving the agent runtime, frontend context interface, data persistence layer, and the integration points between them. Applies clean architecture principles with the agent as the central domain entity.

## Key Rules

1. **Three-Layer Architecture**: Every agent-first application has three layers: (a) Context Interface Layer (frontend), (b) Agent Runtime Layer (backend core), (c) Data & Integration Layer (persistence + external services). Dependencies flow inward: Context Interface -> Agent Runtime -> Data Layer. Never let the Data Layer depend on the Context Interface.

2. **Agent Runtime Is the Core Domain**: In clean architecture terms, the agent runtime (system prompts, tool definitions, orchestration logic) is the domain layer. It must not depend on framework-specific code (no FastAPI imports in agent logic, no React imports in tool implementations). Framework code adapts to the agent core, not vice versa.

3. **API Design for Streaming**: Agent responses take 1-15 seconds. All agent-facing API endpoints must support Server-Sent Events (SSE) or WebSocket streaming. Do NOT use request-response for agent interactions -- users need immediate feedback.

4. **Database Per Concern**: Use separate database schemas (or databases) for: (a) application data (users, projects, settings) -- PostgreSQL/SQLite, (b) vector embeddings (RAG pipeline) -- ChromaDB/pgvector, (c) agent state (conversation history, tool call logs) -- PostgreSQL/Redis. Never store embeddings in the application database.

5. **Environment Variables for All Secrets**: API keys, database URLs, and model configurations must come from environment variables, never hardcoded. Use `.env` files for development, secret managers (Vault, AWS Secrets Manager) for production. Validate all required env vars at startup.

6. **Project Scaffolding Must Be Framework-Appropriate**: Use the framework's official scaffolding command. Do not manually create project structures. Specific commands: `npx create-next-app@latest` (Next.js), `python -m fastapi` or manual for FastAPI, `npm create tauri-app` (Tauri), `npx create-electron-app` (Electron).

## Decision Framework

### Choosing a Backend Framework

```
What language was selected in tech-stack-decision.json?
|
+-- Python
|   |
|   +-- Need REST API + WebSocket? --> FastAPI + uvicorn
|   |   Install: pip install fastapi uvicorn[standard]
|   |   Strengths: async, auto OpenAPI docs, Pydantic integration
|   |
|   +-- Need simple HTTP only?     --> Flask or FastAPI (prefer FastAPI)
|   +-- Need GraphQL?              --> FastAPI + Strawberry
|
+-- TypeScript/JavaScript
|   |
|   +-- Full-stack with React?     --> Next.js (API routes + React)
|   +-- API-only backend?          --> Express.js or Hono
|   +-- Need WebSocket natively?   --> Next.js + Socket.io or Hono
|
+-- Rust (Tauri backend)
    --> Tauri commands (Rust functions exposed to frontend)
        No additional web framework needed for desktop apps
```

### Choosing a Database

```
What data needs to be stored?
|
+-- Application data (users, projects, settings)
|   |
|   +-- Simple project, <10 tables     --> SQLite (via SQLAlchemy or Prisma)
|   +-- Production, multi-user, >10 tables --> PostgreSQL
|   +-- TypeScript project              --> Prisma ORM
|   +-- Python project                  --> SQLAlchemy + Alembic
|
+-- Vector embeddings (RAG)
|   |
|   +-- Prototyping, <100K documents    --> ChromaDB (embedded)
|   +-- Production with PostgreSQL      --> pgvector extension
|   +-- Managed cloud                   --> Pinecone
|
+-- Conversation history / agent state
|   |
|   +-- Simple (last N messages)        --> In-memory or SQLite
|   +-- Production, shared state        --> PostgreSQL or Redis
|   +-- LangGraph state persistence     --> PostgreSQL (LangGraph checkpointer)
|
+-- Caching / session data
    --> Redis (if needed), or in-memory for simple projects
```

### Project Directory Structure

```
What type of project?
|
+-- Python backend + separate frontend
|   --> Monorepo with separate packages:
|       project/
|         backend/          # FastAPI application
|           app/
|             agents/       # Agent runtime (system prompts, tools, orchestration)
|             api/          # API routes (HTTP + WebSocket endpoints)
|             models/       # Pydantic models + SQLAlchemy ORM models
|             services/     # Business logic, RAG pipeline, provider abstraction
|             core/         # Config, security, dependencies
|           tests/
|           alembic/        # Database migrations
|         frontend/         # React/Svelte application
|           src/
|             components/   # Context windows, context tools
|             hooks/        # Data fetching, WebSocket, state management
|             pages/        # Route pages
|         shared/           # Shared types/schemas (OpenAPI generated)
|
+-- Next.js full-stack
|   --> Next.js monolith:
|       project/
|         src/
|           app/            # Next.js app router pages
|           components/     # Context windows, context tools
|           lib/
|             agents/       # Agent runtime
|             tools/        # Tool implementations
|             rag/          # RAG pipeline
|             db/           # Database client + schema
|         prisma/           # Prisma schema + migrations
|         tests/
|
+-- CLI tool (Python)
    --> Simple package:
        project/
          src/
            cli.py          # CLI entry point (click/typer)
            agent.py        # Agent runtime
            tools.py        # Tool implementations
          tests/
```

## Procedures

### Procedure 1: Scaffold a Python Backend for Agent-First App

1. **Create the project structure**:
   ```bash
   mkdir -p backend/app/{agents,api,models,services,core} backend/tests backend/alembic
   ```

2. **Set up dependencies** (`backend/requirements.txt`):
   ```
   fastapi>=0.110.0
   uvicorn[standard]>=0.29.0
   pydantic>=2.0.0
   sqlalchemy>=2.0.0
   alembic>=1.13.0
   anthropic>=0.40.0
   litellm>=1.30.0
   chromadb>=1.0.0
   python-dotenv>=1.0.0
   ```

3. **Create the config module** (`backend/app/core/config.py`):
   ```python
   from pydantic_settings import BaseSettings

   class Settings(BaseSettings):
       # Application
       app_name: str = "AI-Centric App"
       debug: bool = False

       # Database
       database_url: str = "sqlite:///./app.db"

       # AI Providers
       anthropic_api_key: str = ""
       openai_api_key: str = ""
       default_model: str = "claude-sonnet-4-20250514"

       # RAG
       chroma_persist_dir: str = "./chroma_data"
       embedding_model: str = "all-MiniLM-L6-v2"

       class Config:
           env_file = ".env"

   settings = Settings()
   ```

4. **Create the FastAPI application** (`backend/app/main.py`):
   ```python
   from fastapi import FastAPI
   from fastapi.middleware.cors import CORSMiddleware

   app = FastAPI(title="AI-Centric App")

   app.add_middleware(
       CORSMiddleware,
       allow_origins=["http://localhost:3000"],  # frontend dev server
       allow_methods=["*"],
       allow_headers=["*"],
   )

   @app.get("/health")
   async def health():
       return {"status": "ok"}
   ```

5. **Create the agent runtime** (`backend/app/agents/runtime.py`):
   ```python
   from litellm import completion
   from app.core.config import settings

   async def invoke_agent(agent_config: dict, messages: list, context: dict) -> dict:
       """Invoke an agent with messages and context data."""
       system_prompt = agent_config["system_prompt"]
       tools = agent_config.get("tools", [])

       # Inject context into system prompt
       if context:
           context_str = json.dumps(context, indent=2)
           system_prompt += f"\n\n<user_context>\n{context_str}\n</user_context>"

       response = await completion(
           model=agent_config.get("model", settings.default_model),
           messages=[{"role": "system", "content": system_prompt}] + messages,
           tools=tools if tools else None,
           stream=True  # Always stream for UX
       )
       return response
   ```

6. **Create streaming endpoint** (`backend/app/api/chat.py`):
   ```python
   from fastapi import APIRouter
   from fastapi.responses import StreamingResponse

   router = APIRouter()

   @router.post("/api/chat")
   async def chat(request: ChatRequest):
       async def event_stream():
           async for chunk in invoke_agent(agent_config, request.messages, request.context):
               yield f"data: {json.dumps(chunk)}\n\n"
           yield "data: [DONE]\n\n"

       return StreamingResponse(event_stream(), media_type="text/event-stream")
   ```

### Procedure 2: Implement the Provider Abstraction Layer

1. **Use LiteLLM as the abstraction** (`backend/app/services/llm.py`):
   ```python
   import litellm
   from app.core.config import settings

   # Configure providers
   litellm.set_verbose = settings.debug

   # Provider-agnostic completion call
   async def complete(
       model: str,
       messages: list,
       tools: list = None,
       temperature: float = 0.0,
       max_tokens: int = 2048,
       stream: bool = True
   ):
       return await litellm.acompletion(
           model=model,
           messages=messages,
           tools=tools,
           temperature=temperature,
           max_tokens=max_tokens,
           stream=stream
       )
   ```

2. **Define model aliases** for easy switching:
   ```python
   MODEL_ALIASES = {
       "fast": "claude-haiku-3.5",
       "standard": "claude-sonnet-4-20250514",
       "powerful": "claude-opus-4",
       "local": "ollama/llama3.3:70b",
       "cheap": "gpt-4o-mini"
   }
   ```

3. **Implement fallback** chain:
   ```python
   FALLBACK_CHAIN = [
       "claude-sonnet-4-20250514",
       "gpt-4o",
       "ollama/llama3.3:70b"
   ]

   async def complete_with_fallback(messages, tools=None, **kwargs):
       for model in FALLBACK_CHAIN:
           try:
               return await complete(model=model, messages=messages, tools=tools, **kwargs)
           except Exception as e:
               if model == FALLBACK_CHAIN[-1]:
                   raise  # Last resort failed
               continue  # Try next provider
   ```

### Procedure 3: Set Up Database with Migrations

1. **Define SQLAlchemy models** (`backend/app/models/database.py`):
   ```python
   from sqlalchemy import Column, String, DateTime, JSON, ForeignKey
   from sqlalchemy.orm import declarative_base, relationship
   import datetime

   Base = declarative_base()

   class Conversation(Base):
       __tablename__ = "conversations"
       id = Column(String, primary_key=True)
       user_id = Column(String, nullable=False, index=True)
       agent_id = Column(String, nullable=False)
       created_at = Column(DateTime, default=datetime.datetime.utcnow)
       messages = relationship("Message", back_populates="conversation")

   class Message(Base):
       __tablename__ = "messages"
       id = Column(String, primary_key=True)
       conversation_id = Column(String, ForeignKey("conversations.id"))
       role = Column(String, nullable=False)  # "user", "assistant", "system"
       content = Column(String, nullable=False)
       tool_calls = Column(JSON, nullable=True)
       created_at = Column(DateTime, default=datetime.datetime.utcnow)
       conversation = relationship("Conversation", back_populates="messages")
   ```

2. **Initialize Alembic**:
   ```bash
   cd backend && alembic init alembic
   ```

3. **Create initial migration**:
   ```bash
   alembic revision --autogenerate -m "initial schema"
   alembic upgrade head
   ```

## Reference Tables

### Technology Stack Combinations

| Project Type | Frontend | Backend | Database | Agent Framework | Build Tool |
|-------------|----------|---------|----------|----------------|------------|
| Web (Python) | React + Vite | FastAPI | PostgreSQL + ChromaDB | LangGraph | pip/uv |
| Web (TypeScript) | Next.js | Next.js API routes | PostgreSQL + ChromaDB | Vercel AI SDK | pnpm |
| Desktop | React + Tauri | Tauri (Rust) | SQLite + ChromaDB | Direct SDK | cargo + pnpm |
| CLI | N/A | Python | SQLite + ChromaDB | Direct SDK | pip/uv |
| Mobile | React Native | FastAPI (remote) | PostgreSQL + ChromaDB | LangGraph | pnpm |

### API Endpoint Patterns for Agent-First Apps

| Endpoint | Method | Purpose | Response Type |
|----------|--------|---------|---------------|
| `/api/chat` | POST | Send message to agent | SSE stream |
| `/api/chat/{id}/history` | GET | Get conversation history | JSON |
| `/api/agents` | GET | List available agents | JSON |
| `/api/agents/{id}/config` | GET | Get agent configuration | JSON |
| `/api/context` | POST | Submit context tool data | JSON |
| `/api/tools/{name}/execute` | POST | Direct tool execution | JSON |
| `/api/documents` | GET/POST | Document CRUD for RAG | JSON |
| `/api/health` | GET | Health check | JSON |
| `/ws/chat` | WebSocket | Bidirectional streaming | Binary/text frames |

## Failure Modes

| Failure | Symptoms | Root Cause | Fix |
|---------|----------|------------|-----|
| Agent logic coupled to framework | Cannot test agent without running FastAPI, cannot switch frameworks | Agent runtime imports FastAPI-specific code | Move agent logic to pure Python module. Framework code only in API layer. Test agent with direct function calls. |
| No streaming support | Users wait 5-15 seconds with no feedback, perceive app as broken | Agent endpoint uses request-response instead of SSE/WebSocket | Implement SSE for all agent-facing endpoints. Show typing indicator immediately. Stream tokens as they arrive. |
| Hardcoded API keys | Keys committed to git, exposed in client-side code, or in Docker images | Secrets stored in source files or config files instead of env vars | Move all secrets to environment variables. Add `.env` to `.gitignore`. Validate env vars at app startup. |
| Single database for everything | Slow queries, schema conflicts between app data and vector data | Embeddings stored in same database as application data | Separate ChromaDB (or pgvector schema) from application schema. Use dedicated connection pools. |
| CORS blocking frontend | Frontend gets 403/CORS errors when calling backend API | CORS middleware not configured, or origins list too restrictive | Configure CORS middleware with specific frontend origin. For dev: `http://localhost:3000`. For prod: actual domain. |
| Database migration conflicts | Schema changes fail, data loss on upgrade | No migration system, or manual schema changes | Use Alembic (Python) or Prisma Migrate (TypeScript). Never modify schema directly. Always create migrations. |

## Examples

### Example 1: Full-Stack Architecture for a Document Q&A Web App

**Tech Stack** (from tech-stack-decision.json):
- Frontend: Next.js 14 (React)
- Backend: FastAPI (Python)
- Database: PostgreSQL + ChromaDB
- AI: Claude Sonnet via LiteLLM

**Architecture Diagram** (text):
```
[Next.js Frontend]
    |
    | SSE / REST
    |
[FastAPI Backend]
    |
    +-- /api/chat (SSE) --> [Agent Runtime]
    |                           |
    |                           +-- LiteLLM --> [Claude API]
    |                           +-- ChromaDB --> [RAG retrieval]
    |                           +-- Tool Executor --> [Action tools]
    |
    +-- /api/documents (REST) --> [Document Service]
    |                                |
    |                                +-- PostgreSQL (metadata)
    |                                +-- ChromaDB (embeddings)
    |
    +-- /api/auth (REST) --> [Auth Service]
                               |
                               +-- PostgreSQL (users)
```

**Key decisions**:
- SSE for chat streaming (simpler than WebSocket for unidirectional streaming)
- LiteLLM as provider abstraction (swap Claude for GPT-4o with one config change)
- ChromaDB embedded (no separate server for initial deployment)
- PostgreSQL for application data (user accounts, document metadata)
