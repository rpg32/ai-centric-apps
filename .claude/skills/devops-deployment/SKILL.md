---
name: devops-deployment
description: Deployment patterns for AI-centric applications including containerization, CI/CD pipelines, secret management, LLM cost monitoring, and platform-specific packaging for web, desktop, mobile, and CLI targets.
user-invocable: false
---

# DevOps and Deployment for Agent-First Applications

## Purpose

Enable Claude to package, deploy, and maintain AI-centric applications across target platforms (web containers, desktop installers, mobile apps, CLI packages) with CI/CD automation, secure secret management, and LLM cost monitoring.

## Key Rules

1. **Container-First for Web Applications**: All web-deployed agent apps must be containerized with Docker. Use multi-stage builds to keep images small (<500MB). Base image: `python:3.12-slim` for Python backends, `node:20-slim` for Node.js.

2. **Secrets Never in Source or Images**: API keys (Anthropic, OpenAI), database credentials, and signing keys must be passed via environment variables or secret managers. Scan every commit for secrets using pre-commit hooks. Use `.env.example` (with placeholder values) to document required variables.

3. **CI/CD Pipeline Must Include Tests and Eval**: Every pipeline must have at minimum: (a) lint, (b) unit tests, (c) build, (d) deploy. For agent apps, add: (e) agent evaluation run against benchmark dataset. Fail the pipeline if any threshold is not met.

4. **LLM Cost Monitoring Is Mandatory**: Every deployed agent app must track token usage and costs per request, per agent, and per day. Set alerts at 80% of daily budget. Use Langfuse or LiteLLM proxy for monitoring.

5. **Health Check Endpoints**: Every deployed service must expose `/health` (returns HTTP 200 if service is running) and `/ready` (returns HTTP 200 only when all dependencies are connected: database, vector store, LLM provider). Kubernetes liveness/readiness probes use these.

6. **Deployment Must Be Reproducible**: Running `docker compose up` or the deploy command twice produces the same result. Pin all dependency versions. Use exact image tags, not `latest`. Include database migration in the startup sequence.

## Decision Framework

### Choosing a Deployment Target

```
What platform does tech-stack-decision.json specify?
|
+-- Cloud-hosted web application
|   --> Docker + Docker Compose (simple) or Kubernetes (scaled)
|       Simple (1-10 users): Docker Compose on a single VM
|       Medium (10-1000 users): Docker Compose with load balancer
|       Large (1000+ users): Kubernetes with auto-scaling
|
+-- Desktop application (Electron)
|   --> Electron Forge for packaging
|       Windows: .exe installer (NSIS)
|       macOS: .dmg
|       Linux: .AppImage or .deb
|
+-- Desktop application (Tauri)
|   --> Tauri bundler
|       Windows: .msi installer
|       macOS: .dmg
|       Linux: .AppImage or .deb
|
+-- CLI tool (Python)
|   --> PyPI package or standalone binary
|       PyPI: pip install your-tool
|       Binary: PyInstaller for standalone executable
|
+-- CLI tool (Node.js)
|   --> npm package
|       npm: npx your-tool or npm install -g your-tool
|
+-- Mobile app
    --> Platform app stores
        iOS: TestFlight -> App Store Connect
        Android: Google Play Internal Testing -> Production
```

### Docker Compose vs. Kubernetes

```
How many concurrent users?
|
+-- <100 users, single team
|   --> Docker Compose on a VM
|       Pro: simple, one file, easy debugging
|       Con: no auto-scaling, single point of failure
|
+-- 100-1000 users, needs uptime
|   --> Docker Compose + Traefik/Nginx load balancer
|       Pro: reasonable scaling, still simple
|       Con: manual scaling, limited orchestration
|
+-- 1000+ users or enterprise SLA
    --> Kubernetes (EKS, GKE, AKS)
        Pro: auto-scaling, rolling updates, self-healing
        Con: complexity, requires K8s expertise
```

## Procedures

### Procedure 1: Create a Docker Deployment for a Python Agent App

1. **Write the Dockerfile** (`Dockerfile`):
   ```dockerfile
   # Stage 1: Build
   FROM python:3.12-slim AS builder
   WORKDIR /build
   COPY requirements.txt .
   RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

   # Stage 2: Runtime
   FROM python:3.12-slim
   WORKDIR /app

   # Copy installed packages from builder
   COPY --from=builder /install /usr/local

   # Copy application code
   COPY backend/app ./app
   COPY backend/alembic ./alembic
   COPY backend/alembic.ini .

   # Non-root user for security
   RUN useradd -m appuser
   USER appuser

   EXPOSE 8000

   # Health check
   HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
     CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

   CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
   ```

2. **Write docker-compose.yml**:
   ```yaml
   version: "3.8"
   services:
     app:
       build: .
       ports:
         - "8000:8000"
       env_file: .env
       depends_on:
         db:
           condition: service_healthy
       volumes:
         - chroma_data:/app/chroma_data

     db:
       image: postgres:16-alpine
       environment:
         POSTGRES_DB: ${DB_NAME:-aiapp}
         POSTGRES_USER: ${DB_USER:-aiapp}
         POSTGRES_PASSWORD: ${DB_PASSWORD}
       volumes:
         - postgres_data:/var/lib/postgresql/data
       healthcheck:
         test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-aiapp}"]
         interval: 5s
         timeout: 5s
         retries: 5

     frontend:
       build:
         context: ./frontend
         dockerfile: Dockerfile
       ports:
         - "3000:3000"
       environment:
         - NEXT_PUBLIC_API_URL=http://app:8000

   volumes:
     postgres_data:
     chroma_data:
   ```

3. **Create .env.example** (commit this, NOT .env):
   ```bash
   # AI Provider Keys
   ANTHROPIC_API_KEY=sk-ant-your-key-here
   OPENAI_API_KEY=sk-your-key-here

   # Database
   DB_NAME=aiapp
   DB_USER=aiapp
   DB_PASSWORD=change-me-in-production

   # Application
   APP_ENV=production
   DEFAULT_MODEL=claude-sonnet-4-20250514
   ```

4. **Deploy**:
   ```bash
   docker compose up -d --build
   docker compose exec app alembic upgrade head  # Run migrations
   ```

### Procedure 2: Create a CI/CD Pipeline (GitHub Actions)

1. **Write `.github/workflows/ci.yml`**:
   ```yaml
   name: CI/CD Pipeline
   on:
     push:
       branches: [main]
     pull_request:
       branches: [main]

   jobs:
     lint:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: actions/setup-python@v5
           with:
             python-version: "3.12"
         - run: pip install ruff
         - run: ruff check backend/
         - run: ruff format --check backend/

     test:
       runs-on: ubuntu-latest
       needs: lint
       steps:
         - uses: actions/checkout@v4
         - uses: actions/setup-python@v5
           with:
             python-version: "3.12"
         - run: pip install -r backend/requirements.txt -r backend/requirements-dev.txt
         - run: pytest backend/tests --cov=backend/app --cov-report=xml
         - name: Check coverage threshold
           run: |
             python -c "
             import xml.etree.ElementTree as ET
             tree = ET.parse('coverage.xml')
             rate = float(tree.getroot().attrib['line-rate'])
             assert rate > 0.70, f'Coverage {rate:.0%} below 70% threshold'
             "

     agent-eval:
       runs-on: ubuntu-latest
       needs: test
       if: github.ref == 'refs/heads/main'
       steps:
         - uses: actions/checkout@v4
         - uses: actions/setup-node@v4
           with:
             node-version: "20"
         - run: npx promptfoo@latest eval --config eval/promptfooconfig.yaml --output eval/results.json
           env:
             ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
         - name: Check eval thresholds
           run: |
             python -c "
             import json
             with open('eval/results.json') as f:
                 r = json.load(f)
             total = len(r['results'])
             passed = sum(1 for x in r['results'] if x['success'])
             acc = passed/total
             assert acc > 0.90, f'Accuracy {acc:.0%} below 90%'
             "

     deploy:
       runs-on: ubuntu-latest
       needs: [test, agent-eval]
       if: github.ref == 'refs/heads/main'
       steps:
         - uses: actions/checkout@v4
         - name: Deploy to production
           run: |
             # Platform-specific deployment command
             docker compose -f docker-compose.prod.yml up -d --build
   ```

### Procedure 3: Set Up LLM Cost Monitoring with Langfuse

1. **Install Langfuse**:
   ```bash
   pip install langfuse
   ```

2. **Instrument the agent runtime**:
   ```python
   from langfuse import Langfuse
   from langfuse.decorators import observe

   langfuse = Langfuse(
       public_key=os.environ["LANGFUSE_PUBLIC_KEY"],
       secret_key=os.environ["LANGFUSE_SECRET_KEY"],
       host=os.environ.get("LANGFUSE_HOST", "https://cloud.langfuse.com")
   )

   @observe()
   async def invoke_agent(agent_config, messages, context):
       """Langfuse automatically traces this function call."""
       response = await litellm.acompletion(
           model=agent_config["model"],
           messages=messages,
           tools=agent_config.get("tools"),
           metadata={"agent_id": agent_config["id"]}  # Langfuse tags
       )
       return response
   ```

3. **Set up cost alerts**:
   - Daily budget: define per-agent and total
   - Alert at 80%: send notification (email, Slack, webhook)
   - Hard limit at 100%: disable non-essential agents, fall back to cheaper models

4. **Monitor dashboards**:
   - Token usage per agent per day
   - Cost per request (average and P95)
   - Latency per agent
   - Error rate per provider

### Procedure 4: Generate API Documentation

1. **FastAPI auto-generates OpenAPI spec**:
   ```python
   # In main.py - already available at /docs and /openapi.json
   app = FastAPI(
       title="AI-Centric App API",
       version="1.0.0",
       description="API for the AI-Centric application"
   )
   ```

2. **Export and validate**:
   ```bash
   # Export OpenAPI spec
   python -c "
   import json
   from app.main import app
   spec = app.openapi()
   with open('api-spec.yaml', 'w') as f:
       import yaml
       yaml.dump(spec, f, default_flow_style=False)
   "

   # Validate
   pip install openapi-spec-validator
   python -c "
   from openapi_spec_validator import validate
   from openapi_spec_validator.readers import read_from_filename
   spec, _ = read_from_filename('api-spec.yaml')
   validate(spec)
   print('OpenAPI spec is valid')
   "
   ```

## Reference Tables

### Deployment Checklist

| Item | Required | Check Command |
|------|----------|--------------|
| Docker builds | Yes | `docker build -t app .` (exit 0) |
| Health endpoint | Yes | `curl http://localhost:8000/health` (HTTP 200) |
| Ready endpoint | Yes | `curl http://localhost:8000/ready` (HTTP 200) |
| Env vars documented | Yes | `.env.example` exists with all required vars |
| No hardcoded secrets | Yes | `grep -r "sk-" src/` returns 0 results |
| Database migrations | Yes | `alembic upgrade head` (exit 0) |
| CI/CD pipeline | Yes | `.github/workflows/ci.yml` exists and valid |
| API spec generated | Yes | `api-spec.yaml` is valid OpenAPI 3.1 |
| Cost monitoring | Yes | Langfuse or equivalent configured |
| Non-root container | Yes | `USER appuser` in Dockerfile |

### Docker Image Size Targets

| Application Type | Target Size | Base Image |
|-----------------|-------------|------------|
| Python backend | <300MB | `python:3.12-slim` |
| Node.js backend | <250MB | `node:20-slim` |
| Frontend (static) | <50MB | `nginx:alpine` |
| Full stack (compose) | <600MB total | Multi-stage builds |

### Secret Management by Environment

| Environment | Method | Tool |
|-------------|--------|------|
| Development | `.env` file (gitignored) | python-dotenv |
| CI/CD | GitHub Secrets / GitLab CI vars | Platform-native |
| Production (simple) | Environment variables in Docker Compose | Docker/systemd |
| Production (enterprise) | Secret manager | HashiCorp Vault, AWS Secrets Manager |

## Failure Modes

| Failure | Symptoms | Root Cause | Fix |
|---------|----------|------------|-----|
| API key in Docker image | Secret visible with `docker inspect` or layer extraction | Key copied into image during build, or set as ARG instead of env var | Use multi-stage build. Pass secrets only at runtime via env vars. Scan images with `trivy`. |
| LLM costs exceed budget | Monthly bill 5-10x expected, alerts fire daily | No cost monitoring, no per-request budget, or agent in infinite loop | Implement Langfuse monitoring. Set max_tokens on every request. Add iteration limits to agent loops. Set daily cost caps. |
| Container fails to start | Health check fails, logs show missing env var or connection refused | Missing environment variable, or dependency (DB, vector store) not ready | Validate all env vars at startup. Use `depends_on: condition: service_healthy`. Add retry logic for external connections. |
| CI/CD deploys broken code | Production outage after deploy, tests passed but functionality broken | Agent eval not in CI pipeline, or eval dataset does not cover the changed functionality | Add agent eval as a required CI step. Update eval dataset when adding features. Use staging environment for pre-prod validation. |
| Database migration fails | Application crashes on startup with schema mismatch errors | Migration not run after deploy, or migration conflicts from concurrent deploys | Run migrations as part of deployment script (before app start). Use advisory locks to prevent concurrent migrations. |
| CORS/network misconfiguration | Frontend cannot reach backend, 403 errors, WebSocket fails | Docker network isolation, wrong port mapping, or CORS origins not configured | Verify docker-compose networking. Set CORS origins to match frontend URL. Test with `curl` from inside the container. |

## Examples

### Example 1: Complete Deployment for a Document Q&A Web App

**Stack**: FastAPI + Next.js + PostgreSQL + ChromaDB

**Deployment architecture**:
```
[Nginx Reverse Proxy :443]
    |
    +-- /api/* --> [FastAPI Container :8000]
    |                |
    |                +-- [PostgreSQL Container :5432]
    |                +-- [ChromaDB Volume /data/chroma]
    |
    +-- /* -----> [Next.js Container :3000]
```

**CI/CD pipeline stages**: lint (30s) -> test (2m) -> build images (3m) -> agent eval (5m) -> deploy (2m) = ~12 minutes total.

**Cost monitoring**: Langfuse tracks $0.012 average per request. Daily budget: $50. Alert at $40. Hard limit at $60 (falls back to gpt-4o-mini).

**Result**: Application accessible at `https://app.example.com`. Health check passing. API spec at `/docs`. Langfuse dashboard showing real-time costs.
