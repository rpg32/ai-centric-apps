---
name: llm-api-integration
description: Patterns for integrating LLM provider APIs (Anthropic Claude, OpenAI, Ollama) including authentication, streaming, token management, rate limiting, cost optimization, and provider abstraction.
user-invocable: false
---

# LLM API Integration

## Purpose

Enable Claude to implement reliable connections to LLM providers (Anthropic, OpenAI, Ollama), configure streaming responses, manage token budgets and costs, handle rate limits, and build provider abstraction layers that prevent vendor lock-in.

## Key Rules

1. **Provider Abstraction Is Non-Negotiable**: All LLM calls must go through an abstraction layer (LiteLLM recommended, Vercel AI SDK for TypeScript). Direct `anthropic.messages.create()` calls in application logic create lock-in. The only place provider-specific code should exist is inside the abstraction layer.

2. **Always Use Streaming**: For all user-facing agent interactions, use streaming responses. Users perceive a 1-second time-to-first-token as fast, even if the full response takes 10 seconds. Non-streaming responses feel broken after 3 seconds of silence.

3. **Set max_tokens on Every Request**: Never send a request without `max_tokens`. Default: 2048 for standard responses, 1024 for tool-calling, 4096 for generation tasks. Unbounded responses can cost 10x expected and take 30+ seconds.

4. **Token Counting Before Sending**: Estimate prompt token count before sending. If prompt exceeds 80% of context window, summarize or truncate. Use `tiktoken` for OpenAI models, Anthropic's token counter for Claude. Rule of thumb: 1 token = ~4 English characters.

5. **Rate Limit Handling**: Implement exponential backoff with jitter. On 429 status: wait 2^attempt * (1 + random(0,1)) seconds. Maximum 3 retries. After 3 retries, return error to user. Never retry in a tight loop.

6. **API Key Rotation**: Support multiple API keys per provider for higher rate limits. Round-robin or least-recently-used selection. Store keys in environment variables as comma-separated values: `ANTHROPIC_API_KEYS=key1,key2,key3`.

7. **Cost Tracking Per Request**: Log token usage (input and output) for every request. Calculate cost: `cost = (input_tokens / 1M) * input_price + (output_tokens / 1M) * output_price`. Aggregate by agent, user, and day.

## Decision Framework

### Choosing a Provider for a Task

```
What is the task?
|
+-- Complex reasoning, long document analysis
|   --> claude-opus-4 or o1
|       Cost: ~$15/$75 per 1M tokens (input/output)
|       Latency: 5-15s
|
+-- Standard tool-calling, analysis, code generation
|   --> claude-sonnet-4 or gpt-4o
|       Cost: ~$3/$15 per 1M tokens
|       Latency: 2-5s
|
+-- Classification, routing, simple extraction
|   --> claude-haiku-3.5 or gpt-4o-mini
|       Cost: ~$0.80/$4 per 1M tokens
|       Latency: 0.5-2s
|
+-- Privacy-sensitive, offline, zero-cost development
|   --> Ollama (llama3.3:70b, mistral:7b)
|       Cost: $0 per token (hardware only)
|       Latency: 1-10s depending on model and hardware
|
+-- Need embeddings
    --> text-embedding-3-small (OpenAI) or all-MiniLM-L6-v2 (local)
```

### Provider Abstraction Architecture

```
Application Code
    |
    v
[Provider Abstraction Layer]  <-- LiteLLM or Vercel AI SDK
    |
    +-- Anthropic API (Claude models)
    |     Auth: ANTHROPIC_API_KEY header
    |     Endpoint: https://api.anthropic.com/v1/messages
    |
    +-- OpenAI API (GPT models)
    |     Auth: OPENAI_API_KEY header
    |     Endpoint: https://api.openai.com/v1/chat/completions
    |
    +-- Ollama (local models)
          Auth: none (localhost)
          Endpoint: http://localhost:11434/v1/chat/completions
          Note: OpenAI-compatible API, use openai SDK with base_url override
```

## Procedures

### Procedure 1: Set Up LiteLLM Provider Abstraction

1. **Install**:
   ```bash
   pip install litellm
   ```

2. **Configure providers** (`app/services/llm.py`):
   ```python
   import litellm
   import os

   # LiteLLM reads API keys from environment variables automatically:
   # ANTHROPIC_API_KEY, OPENAI_API_KEY

   # For Ollama, no API key needed:
   # litellm uses "ollama/" prefix to route to localhost:11434

   async def complete(
       model: str,
       messages: list,
       tools: list | None = None,
       temperature: float = 0.0,
       max_tokens: int = 2048,
       stream: bool = True
   ) -> dict | AsyncGenerator:
       """Provider-agnostic completion call."""
       response = await litellm.acompletion(
           model=model,
           messages=messages,
           tools=tools,
           temperature=temperature,
           max_tokens=max_tokens,
           stream=stream
       )
       return response
   ```

3. **Model name mapping** (LiteLLM model strings):
   ```python
   # Anthropic models
   "claude-sonnet-4-20250514"     # Claude Sonnet 4
   "claude-opus-4"                 # Claude Opus 4
   "claude-haiku-3.5"              # Claude Haiku 3.5

   # OpenAI models
   "gpt-4o"                        # GPT-4o
   "gpt-4o-mini"                   # GPT-4o Mini
   "o1"                            # O1

   # Ollama models (prefix with "ollama/")
   "ollama/llama3.3:70b"           # Llama 3.3 70B
   "ollama/mistral:7b"             # Mistral 7B
   ```

4. **Implement fallback chain**:
   ```python
   async def complete_with_fallback(messages, tools=None, **kwargs):
       models = ["claude-sonnet-4-20250514", "gpt-4o", "ollama/llama3.3:70b"]
       last_error = None
       for model in models:
           try:
               return await complete(model=model, messages=messages, tools=tools, **kwargs)
           except Exception as e:
               last_error = e
               continue
       raise last_error
   ```

### Procedure 2: Implement Streaming Responses

1. **Server-side streaming** (FastAPI + LiteLLM):
   ```python
   from fastapi.responses import StreamingResponse

   @router.post("/api/chat")
   async def chat(request: ChatRequest):
       async def event_generator():
           response = await litellm.acompletion(
               model=request.model or "claude-sonnet-4-20250514",
               messages=request.messages,
               stream=True
           )
           async for chunk in response:
               delta = chunk.choices[0].delta
               if delta.content:
                   yield f"data: {json.dumps({'content': delta.content})}\n\n"
               if delta.tool_calls:
                   yield f"data: {json.dumps({'tool_call': delta.tool_calls[0].dict()})}\n\n"
           yield "data: [DONE]\n\n"

       return StreamingResponse(event_generator(), media_type="text/event-stream")
   ```

2. **Client-side consumption** (JavaScript):
   ```javascript
   const response = await fetch('/api/chat', {
     method: 'POST',
     headers: { 'Content-Type': 'application/json' },
     body: JSON.stringify({ messages, model: 'claude-sonnet-4-20250514' })
   });

   const reader = response.body.getReader();
   const decoder = new TextDecoder();

   while (true) {
     const { done, value } = await reader.read();
     if (done) break;
     const text = decoder.decode(value);
     const lines = text.split('\n').filter(l => l.startsWith('data: '));
     for (const line of lines) {
       const data = line.slice(6); // Remove "data: " prefix
       if (data === '[DONE]') return;
       const parsed = JSON.parse(data);
       if (parsed.content) appendToUI(parsed.content);
     }
   }
   ```

### Procedure 3: Implement Cost Tracking

1. **Log token usage after every request**:
   ```python
   from litellm import completion_cost

   async def tracked_complete(model, messages, **kwargs):
       response = await litellm.acompletion(model=model, messages=messages, **kwargs)

       # Extract usage from response
       usage = response.usage
       cost = completion_cost(completion_response=response)

       # Log to database or monitoring
       await log_usage({
           "model": model,
           "input_tokens": usage.prompt_tokens,
           "output_tokens": usage.completion_tokens,
           "total_tokens": usage.total_tokens,
           "cost_usd": cost,
           "timestamp": datetime.utcnow().isoformat()
       })

       return response
   ```

2. **Set daily budget alerts**:
   ```python
   DAILY_BUDGET_USD = 50.0
   ALERT_THRESHOLD = 0.8  # Alert at 80%

   async def check_budget():
       today_cost = await get_today_total_cost()
       if today_cost > DAILY_BUDGET_USD * ALERT_THRESHOLD:
           await send_alert(f"LLM cost alert: ${today_cost:.2f} of ${DAILY_BUDGET_USD:.2f} budget")
       if today_cost > DAILY_BUDGET_USD:
           await switch_to_fallback_models()  # Downgrade to cheaper models
   ```

## Reference Tables

### Provider API Comparison

| Feature | Anthropic (Claude) | OpenAI | Ollama |
|---------|-------------------|--------|--------|
| Auth header | `x-api-key` | `Authorization: Bearer` | None |
| Streaming | SSE via `stream=True` | SSE via `stream=True` | SSE via `stream=True` |
| Tool calling | `tools` parameter | `tools` parameter | Model-dependent |
| Max context | 200K tokens | 128K tokens | Model-dependent |
| Rate limits | Tier-based (1-4) | Tier-based (1-5) | Hardware-limited |
| Cost tracking | Response includes `usage` | Response includes `usage` | Free |

### Token Estimation Quick Reference

| Content Type | Tokens per Unit | Example |
|-------------|----------------|---------|
| English text | ~1 token per 4 chars | 1000 chars = ~250 tokens |
| Code | ~1 token per 3 chars | 1000 chars = ~333 tokens |
| JSON | ~1 token per 3 chars | 1000 chars = ~333 tokens |
| Conversation turn | 50-200 tokens | Depends on message length |
| System prompt | 500-4000 tokens | Depends on complexity |
| Tool definition | 50-150 tokens per tool | 5 tools = 250-750 tokens |

### Rate Limit Handling

| Status Code | Meaning | Wait Strategy | Max Retries |
|------------|---------|---------------|-------------|
| 429 | Rate limited | Exponential backoff: 2^n * (1 + random) seconds | 3 |
| 500 | Server error | Fixed 2s wait | 2 |
| 503 | Service unavailable | Fixed 5s wait, then try fallback provider | 1 |
| 529 | Overloaded (Anthropic) | Fixed 10s wait | 1 |

## Failure Modes

| Failure | Symptoms | Root Cause | Fix |
|---------|----------|------------|-----|
| Provider Lock-in | Cannot switch providers, app breaks when primary provider has outage | Direct provider API calls throughout codebase | Refactor to use LiteLLM or custom abstraction. All LLM calls through one module. |
| Token Limit Exceeded | API returns 400 error with "maximum context length" message | Prompt + context + history exceeds model's context window | Count tokens before sending. Summarize history. Cap RAG results. Use model with larger context. |
| Rate Limit Storm | 429 errors cascade, all requests fail, users see errors | Burst of requests exceeds provider tier limits | Implement exponential backoff. Add request queue. Consider upgrading provider tier. |
| Streaming Breaks Mid-Response | User sees partial response, then nothing. No error shown. | Network timeout, SSE connection dropped, or server crash | Add heartbeat to SSE stream. Implement client-side reconnection. Show "response interrupted" error. |
| Cost Spike | Monthly bill 5-10x expected, alerts fire daily | No max_tokens set, agent in loop, or verbose prompts | Set max_tokens on every request. Add per-request cost cap. Implement daily budget limits. |
| Ollama Connection Refused | Connection error to localhost:11434 | Ollama not running, or wrong port | Verify: `curl http://localhost:11434/api/tags`. Start Ollama if not running. Check firewall. |

## Examples

### Example 1: Complete Provider Setup with Fallback

**Scenario**: Production app needs Claude as primary, GPT-4o as fallback, Ollama for development.

**Configuration** (`.env`):
```bash
ANTHROPIC_API_KEY=sk-ant-xxx
OPENAI_API_KEY=sk-xxx
DEFAULT_MODEL=claude-sonnet-4-20250514
FALLBACK_MODELS=gpt-4o,ollama/llama3.3:70b
DAILY_BUDGET_USD=50
```

**Usage**: Application calls `complete_with_fallback()`. In production, Claude handles all requests. If Claude API is down, transparent failover to GPT-4o. In development, developers can set `DEFAULT_MODEL=ollama/mistral:7b` for free, offline use.

**Cost tracking**: Langfuse dashboard shows per-request costs. Average: $0.012/request (Claude Sonnet). Alert at $40/day. Hard switch to gpt-4o-mini at $50/day.
