---
name: observability
description: Installation, configuration, and usage of Langfuse for LLM observability including tracing, token tracking, cost monitoring, and latency analysis in AI-centric applications.
user-invocable: false
---

# Observability Tools

## Purpose

Enable Claude to install, configure, and use Langfuse for monitoring AI-centric applications in development and production: tracing LLM calls, tracking token usage and costs, measuring latency, and debugging agent behavior.

## Key Rules

1. **Instrument All LLM Calls**: Every call to an LLM provider must be traced by Langfuse. Use the `@observe()` decorator for Python functions or the LiteLLM callback integration. Uninstrumented calls are invisible to monitoring.
2. **Track Cost Per Agent**: Tag every trace with the agent ID that initiated it. This enables per-agent cost breakdowns and identifies which agents are the most expensive.
3. **Set Budget Alerts Early**: Configure daily cost alerts during development, not just production. Development can spike costs if an agent enters a loop.

## Procedures

### Procedure 1: Install and Configure Langfuse

1. **Install**:
   ```bash
   pip install langfuse
   ```

2. **Sign up for Langfuse Cloud** (free tier) or self-host:
   - Cloud: https://cloud.langfuse.com (free tier: 50K observations/month)
   - Self-host: `docker compose up -f langfuse-docker-compose.yml`

3. **Set environment variables**:
   ```bash
   # .env
   LANGFUSE_PUBLIC_KEY=pk-lf-xxxx
   LANGFUSE_SECRET_KEY=sk-lf-xxxx
   LANGFUSE_HOST=https://cloud.langfuse.com  # or self-hosted URL
   ```

4. **Verify connection**:
   ```python
   from langfuse import Langfuse

   langfuse = Langfuse()
   langfuse.auth_check()  # Returns True if credentials are valid
   print("Langfuse connection: OK")
   ```

### Procedure 2: Instrument Agent Code with @observe

1. **Decorate agent functions**:
   ```python
   from langfuse.decorators import observe, langfuse_context

   @observe()
   async def invoke_agent(agent_id: str, messages: list, context: dict):
       """Langfuse automatically creates a trace for this function."""
       # Tag the trace with agent info
       langfuse_context.update_current_observation(
           metadata={"agent_id": agent_id},
           tags=[agent_id, "production"]
       )

       response = await litellm.acompletion(
           model="claude-sonnet-4-20250514",
           messages=messages,
           stream=True
       )

       return response

   @observe()
   async def execute_tool(tool_name: str, params: dict):
       """Tool execution is a child span of the agent trace."""
       langfuse_context.update_current_observation(
           metadata={"tool": tool_name}
       )

       result = await TOOL_REGISTRY[tool_name](**params)
       return result
   ```

2. **Nested observations create trace hierarchies**:
   ```
   Trace: invoke_agent (agent_id="doc-assistant")
     |-- Span: prepare_context (500ms)
     |-- Generation: litellm.acompletion (3200ms, 1850 tokens)
     |-- Span: execute_tool (tool="search_documents", 200ms)
     |-- Generation: litellm.acompletion (2100ms, 920 tokens)
   ```

### Procedure 3: Integrate with LiteLLM Callbacks

1. **Enable LiteLLM + Langfuse integration**:
   ```python
   import litellm
   from langfuse.callback import CallbackHandler

   langfuse_handler = CallbackHandler()
   litellm.success_callback = [langfuse_handler]
   litellm.failure_callback = [langfuse_handler]
   ```

   This automatically logs every LiteLLM call (model, tokens, cost, latency) to Langfuse without manual instrumentation.

2. **Add user and session tracking**:
   ```python
   response = await litellm.acompletion(
       model="claude-sonnet-4-20250514",
       messages=messages,
       metadata={
           "trace_id": request_id,
           "trace_user_id": user.id,
           "session_id": session.id,
           "tags": ["production", agent_id]
       }
   )
   ```

### Procedure 4: Set Up Cost Monitoring and Alerts

1. **View costs in Langfuse dashboard**:
   - Navigate to: Dashboard > Analytics > Cost
   - Group by: model, user, tags (agent_id)
   - Time range: Last 24 hours, 7 days, 30 days

2. **Implement programmatic cost checking**:
   ```python
   from langfuse import Langfuse
   from datetime import datetime, timedelta

   langfuse = Langfuse()

   def get_daily_cost():
       """Get total LLM cost for today."""
       # Langfuse API: fetch traces for today
       traces = langfuse.fetch_traces(
           from_timestamp=datetime.utcnow().replace(hour=0, minute=0),
           to_timestamp=datetime.utcnow()
       )
       total_cost = sum(t.total_cost or 0 for t in traces.data)
       return total_cost

   def check_budget(daily_limit: float = 50.0):
       cost = get_daily_cost()
       if cost > daily_limit * 0.8:
           send_alert(f"LLM cost warning: ${cost:.2f} of ${daily_limit:.2f} daily budget")
       if cost > daily_limit:
           switch_to_cheaper_models()
           send_alert(f"LLM cost EXCEEDED: ${cost:.2f}. Switched to fallback models.")
   ```

3. **Run cost check periodically**:
   ```python
   # In a background task or cron job
   import asyncio

   async def budget_monitor():
       while True:
           check_budget(daily_limit=50.0)
           await asyncio.sleep(300)  # Check every 5 minutes
   ```

### Procedure 5: Debug Agent Issues with Traces

1. **Find problematic traces**:
   - Filter by: status=error, latency>10s, or cost>$0.10
   - Look at: which tool calls failed, what the model output was, token counts

2. **Common debugging patterns**:
   ```
   Issue: Agent selected wrong tool
   Debug: Open trace -> look at Generation step -> check system prompt
         and user message -> verify tool descriptions are clear

   Issue: Response took >15 seconds
   Debug: Open trace -> check span durations -> identify bottleneck
         (LLM inference? Tool execution? RAG query?)

   Issue: Unexpected cost spike
   Debug: Dashboard > Cost > Group by model -> find expensive model
         Dashboard > Cost > Group by tags -> find expensive agent
   ```

## Reference Tables

### Langfuse API Quick Reference

| Operation | Method | Description |
|-----------|--------|-------------|
| `@observe()` | Decorator | Auto-create trace/span for a function |
| `langfuse_context.update_current_observation()` | Method | Add metadata to current trace |
| `langfuse.trace()` | Method | Manually create a trace |
| `langfuse.span()` | Method | Manually create a span within a trace |
| `langfuse.generation()` | Method | Log an LLM generation |
| `langfuse.score()` | Method | Add a score to a trace (quality rating) |
| `langfuse.fetch_traces()` | Method | Query traces for analysis |

### Key Metrics to Monitor

| Metric | Target | Alert At | Action |
|--------|--------|----------|--------|
| Daily cost | < $50 | $40 (80%) | Investigate; switch to cheaper models at $50 |
| Avg latency (single agent) | < 5s | > 8s | Optimize prompt, use faster model |
| Avg latency (multi agent) | < 15s | > 20s | Parallelize agents, use faster routing model |
| Error rate | < 2% | > 5% | Check provider status, review error traces |
| Avg tokens per request | < 3000 | > 5000 | Optimize prompts, reduce RAG context |

### Langfuse Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `LANGFUSE_PUBLIC_KEY` | Yes | Public API key from Langfuse dashboard |
| `LANGFUSE_SECRET_KEY` | Yes | Secret API key from Langfuse dashboard |
| `LANGFUSE_HOST` | No | API host (default: `https://cloud.langfuse.com`) |
| `LANGFUSE_RELEASE` | No | Release tag for filtering (e.g., `v1.2.0`) |
| `LANGFUSE_DEBUG` | No | Set to `true` for verbose logging |

## Failure Modes

| Failure | Symptoms | Root Cause | Fix |
|---------|----------|------------|-----|
| Traces not appearing | Langfuse dashboard empty, no data | Credentials wrong, or `@observe()` not decorating the right function | Run `langfuse.auth_check()`. Verify env vars. Check decorator is on the entry-point function. |
| Cost shows $0 | Traces exist but no cost data | Model not in Langfuse cost table, or usage not reported | Use LiteLLM callback (it sends usage). For custom providers, manually log token counts. |
| High volume drops traces | Some requests not logged, gaps in data | Langfuse SDK batches and may drop under high load | Increase `flush_interval` or use sync mode for critical traces. Check Langfuse plan limits. |
| Self-hosted Langfuse down | Dashboard unreachable, traces queue locally | Docker container crashed or database full | Check Docker logs. Ensure sufficient disk space. Restart containers. |
| Budget alert not firing | Cost exceeds limit but no alert sent | Budget check not running, or alert endpoint misconfigured | Verify budget monitor background task is running. Test alert endpoint independently. |

## Examples

### Example 1: Fully Instrumented Agent Call

```python
from langfuse.decorators import observe
import litellm

@observe()
async def handle_user_request(user_id: str, message: str, context: dict):
    # Step 1: Prepare prompt (auto-traced as child span)
    prompt = await prepare_prompt(message, context)

    # Step 2: Call LLM (auto-traced via LiteLLM callback)
    response = await litellm.acompletion(
        model="claude-sonnet-4-20250514",
        messages=prompt,
        metadata={"trace_user_id": user_id, "tags": ["qa-agent"]}
    )

    # Step 3: Execute tools if needed (auto-traced)
    if response.choices[0].message.tool_calls:
        tool_result = await execute_tool(response.choices[0].message.tool_calls[0])

    return response

# Langfuse trace shows:
# - Total duration: 4.2s
# - LLM tokens: 1,850 (input: 1,200, output: 650)
# - Cost: $0.012
# - Tool execution: search_documents (200ms)
# - User: user_123
```
