---
name: backend-development
description: Building backend services for agent-first applications using FastAPI or Express, including agent runtime hosting, WebSocket/SSE endpoints, database integration, authentication, and middleware patterns.
user-invocable: false
---

# Backend Development for Agent-First Applications

## Purpose

Enable Claude to implement backend services that host the agent runtime, serve the context interface, manage persistence, and handle authentication. The backend is the bridge between the frontend context interface and the AI provider APIs.

## Key Rules

1. **Agent Runtime Is a Service, Not a Script**: The agent runtime must be a proper service with: health checks, configuration management, graceful shutdown, error handling, and logging. Never run agent logic as standalone scripts invoked by the web framework.

2. **Async Everywhere for Agent Operations**: All LLM calls, tool executions, and database queries in the agent path must be async. A synchronous LLM call blocks the entire server for 2-15 seconds. Use `async def` for all route handlers that touch the agent. FastAPI with uvicorn supports this natively.

3. **Separate API Routers by Concern**: Use router modules: `api/chat.py` (agent interactions), `api/documents.py` (RAG document management), `api/auth.py` (authentication), `api/admin.py` (admin/monitoring). Never put all endpoints in one file.

4. **Request Validation with Pydantic**: Every API endpoint must validate its request body with a Pydantic model. This catches invalid parameters before they reach the agent runtime. Response models are also recommended for consistent API contracts.

5. **Middleware Stack Order Matters**: Apply middleware in this order (first to last): (a) CORS, (b) Authentication, (c) Rate limiting, (d) Request logging, (e) Error handling. Wrong order causes subtle bugs (e.g., CORS before auth means pre-flight requests get rejected).

6. **WebSocket for Bidirectional, SSE for Unidirectional**: Use WebSocket when the frontend needs to send data during streaming (e.g., cancel, provide additional context mid-stream). Use SSE when streaming is purely server-to-client. SSE is simpler and sufficient for most chat patterns.

7. **Database Connections Use Connection Pools**: Never create a new database connection per request. Use connection pools: SQLAlchemy `create_async_engine(pool_size=5, max_overflow=10)` for PostgreSQL, or a singleton for SQLite. ChromaDB uses its own connection management.

## Decision Framework

### API Architecture

```
What type of agent interaction pattern?
|
+-- Simple chat (user sends message, agent responds)
|   --> SSE endpoint (POST /api/chat -> SSE stream)
|       One request, streamed response
|       Most common pattern
|
+-- Interactive chat (user can cancel, provide context mid-stream)
|   --> WebSocket endpoint (WS /ws/chat)
|       Bidirectional, persistent connection
|       More complex but more flexible
|
+-- Background processing (agent works on long task)
|   --> Job queue pattern (POST /api/tasks -> 202, GET /api/tasks/{id})
|       Submit task, poll for status, get result
|       Use for: document processing, batch analysis
|
+-- Real-time collaboration (multiple users + agent)
    --> WebSocket with rooms
        Multiple clients connected to same agent session
        Use for: collaborative editing, shared workspace
```

## Procedures

### Procedure 1: Build a FastAPI Backend for Agent-First App

1. **Project structure**:
   ```
   backend/
     app/
       __init__.py
       main.py              # FastAPI app creation and startup
       core/
         config.py           # Settings from env vars (Pydantic Settings)
         security.py         # Auth middleware, token validation
         dependencies.py     # FastAPI dependency injection
       api/
         chat.py             # Agent chat endpoints (SSE)
         documents.py        # RAG document management
         auth.py             # Authentication endpoints
       agents/
         runtime.py          # Agent invocation, tool execution
         tools.py            # Tool implementations
         prompts/            # System prompt files
       models/
         schemas.py          # Pydantic request/response models
         database.py         # SQLAlchemy ORM models
       services/
         llm.py              # Provider abstraction (LiteLLM wrapper)
         rag.py              # RAG pipeline (ChromaDB operations)
     tests/
     alembic/
     requirements.txt
   ```

2. **Create the main application** (`app/main.py`):
   ```python
   from contextlib import asynccontextmanager
   from fastapi import FastAPI
   from fastapi.middleware.cors import CORSMiddleware
   from app.api import chat, documents, auth
   from app.core.config import settings

   @asynccontextmanager
   async def lifespan(app: FastAPI):
       # Startup: validate config, connect to DB, load agent configs
       validate_required_env_vars()
       await init_database()
       await load_agent_configs()
       yield
       # Shutdown: close connections
       await close_database()

   app = FastAPI(
       title=settings.app_name,
       version="1.0.0",
       lifespan=lifespan
   )

   # Middleware (order matters)
   app.add_middleware(
       CORSMiddleware,
       allow_origins=[settings.frontend_url],
       allow_methods=["*"],
       allow_headers=["*"],
   )

   # Routers
   app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
   app.include_router(chat.router, prefix="/api", tags=["chat"])
   app.include_router(documents.router, prefix="/api/documents", tags=["documents"])

   @app.get("/health")
   async def health():
       return {"status": "ok"}

   @app.get("/ready")
   async def ready():
       db_ok = await check_database()
       llm_ok = await check_llm_provider()
       return {
           "status": "ready" if (db_ok and llm_ok) else "not_ready",
           "database": db_ok,
           "llm_provider": llm_ok
       }
   ```

3. **Create request/response models** (`app/models/schemas.py`):
   ```python
   from pydantic import BaseModel, Field

   class ChatMessage(BaseModel):
       role: str = Field(..., pattern="^(user|assistant|system)$")
       content: str = Field(..., min_length=1, max_length=50000)

   class ChatRequest(BaseModel):
       messages: list[ChatMessage] = Field(..., min_length=1)
       context: dict | None = Field(default=None, description="Context tool data")
       model: str | None = Field(default=None, description="Override default model")
       stream: bool = Field(default=True)

   class ToolCallResponse(BaseModel):
       tool_name: str
       parameters: dict
       result: dict
       duration_ms: int
   ```

4. **Create the chat endpoint** (`app/api/chat.py`):
   ```python
   from fastapi import APIRouter, Depends
   from fastapi.responses import StreamingResponse
   from app.agents.runtime import invoke_agent
   from app.core.dependencies import get_current_user
   from app.models.schemas import ChatRequest

   router = APIRouter()

   @router.post("/chat")
   async def chat(request: ChatRequest, user=Depends(get_current_user)):
       agent_config = await get_agent_config(user.default_agent)

       async def stream():
           async for chunk in invoke_agent(
               config=agent_config,
               messages=[m.dict() for m in request.messages],
               context=request.context,
               user_id=user.id
           ):
               yield f"data: {json.dumps(chunk)}\n\n"
           yield "data: [DONE]\n\n"

       return StreamingResponse(stream(), media_type="text/event-stream")
   ```

### Procedure 2: Implement Authentication

1. **JWT-based auth for API access**:
   ```python
   # app/core/security.py
   from jose import JWTError, jwt
   from fastapi import Depends, HTTPException
   from fastapi.security import HTTPBearer

   security = HTTPBearer()

   async def get_current_user(token = Depends(security)):
       try:
           payload = jwt.decode(token.credentials, settings.jwt_secret, algorithms=["HS256"])
           user_id = payload.get("sub")
           if user_id is None:
               raise HTTPException(status_code=401, detail="Invalid token")
           return await get_user(user_id)
       except JWTError:
           raise HTTPException(status_code=401, detail="Invalid token")
   ```

2. **Rate limiting middleware**:
   ```python
   from slowapi import Limiter
   from slowapi.util import get_remote_address

   limiter = Limiter(key_func=get_remote_address)

   @router.post("/chat")
   @limiter.limit("30/minute")  # 30 agent requests per minute per IP
   async def chat(request: ChatRequest, ...):
       ...
   ```

### Procedure 3: Implement Tool Execution Pipeline

1. **Tool registry** (`app/agents/tools.py`):
   ```python
   from typing import Callable
   import asyncio

   TOOL_REGISTRY: dict[str, Callable] = {}

   def register_tool(name: str):
       def decorator(func):
           TOOL_REGISTRY[name] = func
           return func
       return decorator

   @register_tool("search_documents")
   async def search_documents(query: str, max_results: int = 5, user_id: str = "") -> dict:
       """Search documents scoped to the current user."""
       results = await rag_service.query(query, n_results=max_results, user_id=user_id)
       return {"results": results, "total": len(results)}

   async def execute_tool(tool_name: str, params: dict, user_context: dict) -> dict:
       """Execute a tool with permission checking and error handling."""
       if tool_name not in TOOL_REGISTRY:
           return {"error": f"Unknown tool: {tool_name}", "code": "NOT_FOUND"}

       # Inject user context for permission scoping
       params["user_id"] = user_context["user_id"]

       try:
           result = await asyncio.wait_for(
               TOOL_REGISTRY[tool_name](**params),
               timeout=30.0  # 30-second timeout per tool
           )
           return result
       except asyncio.TimeoutError:
           return {"error": "Tool execution timed out", "code": "TIMEOUT", "recoverable": True}
       except Exception as e:
           return {"error": str(e), "code": "INTERNAL_ERROR", "recoverable": True}
   ```

## Reference Tables

### FastAPI Endpoint Patterns

| Pattern | Method | Path | Response | Use When |
|---------|--------|------|----------|----------|
| Agent chat | POST | `/api/chat` | SSE stream | User sends message to agent |
| Agent cancel | POST | `/api/chat/{id}/cancel` | 200 JSON | User cancels streaming response |
| Get history | GET | `/api/chat/{id}/history` | JSON array | Load conversation history |
| Upload document | POST | `/api/documents` | 201 JSON | Add document to RAG pipeline |
| List documents | GET | `/api/documents` | JSON array | Browse available documents |
| Health check | GET | `/health` | 200 JSON | Liveness probe |
| Readiness check | GET | `/ready` | 200/503 JSON | Readiness probe (all deps up) |

### Python Dependencies for Backend

| Package | Purpose | Version Constraint |
|---------|---------|-------------------|
| fastapi | Web framework | >=0.110.0 |
| uvicorn[standard] | ASGI server | >=0.29.0 |
| pydantic | Data validation | >=2.0.0 |
| pydantic-settings | Config from env | >=2.0.0 |
| sqlalchemy[asyncio] | Async ORM | >=2.0.0 |
| alembic | DB migrations | >=1.13.0 |
| python-jose[cryptography] | JWT auth | >=3.3.0 |
| slowapi | Rate limiting | >=0.1.9 |
| python-dotenv | Env file loading | >=1.0.0 |

## Failure Modes

| Failure | Symptoms | Root Cause | Fix |
|---------|----------|------------|-----|
| Sync LLM call blocks server | Other requests queue, all users experience delays | Agent endpoint uses `def` instead of `async def`, or blocking SDK call | Use `async def` for all agent endpoints. Use async LiteLLM (`acompletion`). Verify uvicorn runs with async workers. |
| DB connection exhaustion | "Too many connections" errors, requests fail | New connection per request, no pool, or pool too small | Use connection pool: `pool_size=5, max_overflow=10`. Close connections properly. Monitor active connections. |
| CORS pre-flight fails | Browser shows CORS error, API works from curl | CORSMiddleware not configured, or wrong origin URL | Add exact frontend URL to `allow_origins`. Include `"OPTIONS"` in `allow_methods`. |
| Agent runtime crashes silently | User gets 500 error, no useful error message | Exception in agent code not caught, no error handler | Wrap agent invocation in try/except. Return structured error JSON. Log full stack trace. |
| SSE connection drops | Partial response, no error shown to user | Proxy timeout (nginx default: 60s), or server timeout | Set proxy timeouts to 120s. Add SSE keepalive (empty comment every 15s). Client-side reconnection. |
| Tool execution timeout | Agent hangs waiting for tool result, user waits indefinitely | Tool makes external call without timeout | Wrap all tool calls in `asyncio.wait_for(coro, timeout=30.0)`. Return timeout error to agent. |

## Examples

### Example 1: Complete Backend Architecture

**Stack**: FastAPI + PostgreSQL + ChromaDB + LiteLLM

**Endpoints**: 8 total (3 chat, 3 documents, 1 health, 1 ready)

**Startup sequence**:
1. Load settings from `.env`
2. Validate required env vars (fail fast if missing)
3. Initialize database connection pool
4. Run pending migrations (`alembic upgrade head`)
5. Initialize ChromaDB client
6. Load agent configurations from `agents/configs/`
7. Start uvicorn on port 8000

**Request flow** (chat):
```
POST /api/chat
  -> Auth middleware (validate JWT)
  -> Rate limit check (30/min/user)
  -> Pydantic validation (ChatRequest)
  -> Agent runtime (invoke_agent)
    -> LiteLLM (streaming completion)
    -> Tool execution (if agent calls tools)
    -> Output filtering (security check)
  -> SSE stream to client
```
