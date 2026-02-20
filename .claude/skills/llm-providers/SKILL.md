---
name: llm-providers
description: Installation, configuration, and usage patterns for Anthropic SDK, OpenAI SDK, LiteLLM, and Ollama for connecting AI-centric applications to LLM providers.
user-invocable: false
---

# LLM Provider Tools

## Purpose

Enable Claude to install, configure, and use the LLM provider SDKs (Anthropic, OpenAI, LiteLLM, Ollama) for building AI-centric applications. Covers authentication, API calls, streaming, tool calling, and error handling for each provider.

## Key Rules

1. **LiteLLM Is the Abstraction Layer**: All application code should call LiteLLM, not provider SDKs directly. LiteLLM normalizes the API across 100+ providers. Direct SDK usage is only for provider-specific features not available through LiteLLM.

2. **API Keys in Environment Variables Only**: Never pass API keys as function arguments in application code. Set them as environment variables: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`. LiteLLM reads these automatically.

3. **Verify Installation Before Use**: After installing any SDK, verify it works with a minimal test call before integrating into the application. A failed import or auth error caught early saves hours of debugging.

## Procedures

### Procedure 1: Install and Verify All Provider SDKs

1. **Install the stack**:
   ```bash
   pip install anthropic openai litellm
   ```

2. **Verify Anthropic SDK**:
   ```bash
   python -c "
   import anthropic
   print(f'Anthropic SDK version: {anthropic.__version__}')
   client = anthropic.Anthropic()  # Reads ANTHROPIC_API_KEY from env
   response = client.messages.create(
       model='claude-haiku-3.5',
       max_tokens=50,
       messages=[{'role': 'user', 'content': 'Say hello'}]
   )
   print(f'Response: {response.content[0].text}')
   print('Anthropic SDK: OK')
   "
   ```
   Expected: Version number printed, response received, "OK" printed.

3. **Verify OpenAI SDK**:
   ```bash
   python -c "
   import openai
   print(f'OpenAI SDK version: {openai.__version__}')
   client = openai.OpenAI()  # Reads OPENAI_API_KEY from env
   response = client.chat.completions.create(
       model='gpt-4o-mini',
       max_tokens=50,
       messages=[{'role': 'user', 'content': 'Say hello'}]
   )
   print(f'Response: {response.choices[0].message.content}')
   print('OpenAI SDK: OK')
   "
   ```

4. **Verify LiteLLM**:
   ```bash
   python -c "
   import litellm
   print(f'LiteLLM version: {litellm.__version__}')
   response = litellm.completion(
       model='claude-haiku-3.5',
       messages=[{'role': 'user', 'content': 'Say hello'}],
       max_tokens=50
   )
   print(f'Response: {response.choices[0].message.content}')
   print('LiteLLM: OK')
   "
   ```

5. **Verify Ollama** (if installed):
   ```bash
   ollama --version
   ollama list
   python -c "
   import openai
   client = openai.OpenAI(base_url='http://localhost:11434/v1', api_key='ollama')
   response = client.chat.completions.create(
       model='mistral:7b',
       max_tokens=50,
       messages=[{'role': 'user', 'content': 'Say hello'}]
   )
   print(f'Response: {response.choices[0].message.content}')
   print('Ollama: OK')
   "
   ```

### Procedure 2: Tool Calling with LiteLLM

1. **Define tools as JSON Schema**:
   ```python
   tools = [
       {
           "type": "function",
           "function": {
               "name": "search_documents",
               "description": "Search project documents. Use when user asks about project content.",
               "parameters": {
                   "type": "object",
                   "properties": {
                       "query": {"type": "string", "description": "Search query"},
                       "max_results": {"type": "integer", "default": 5}
                   },
                   "required": ["query"]
               }
           }
       }
   ]
   ```

2. **Make a tool-calling request**:
   ```python
   import litellm
   import json

   response = litellm.completion(
       model="claude-sonnet-4-20250514",
       messages=[
           {"role": "system", "content": "You are a document assistant."},
           {"role": "user", "content": "Find documents about authentication"}
       ],
       tools=tools,
       tool_choice="auto",
       temperature=0.0
   )

   message = response.choices[0].message

   # Check if model wants to call a tool
   if message.tool_calls:
       tool_call = message.tool_calls[0]
       func_name = tool_call.function.name
       func_args = json.loads(tool_call.function.arguments)
       print(f"Tool call: {func_name}({func_args})")

       # Execute the tool
       tool_result = execute_tool(func_name, func_args)

       # Send tool result back to the model
       messages.append(message.dict())
       messages.append({
           "role": "tool",
           "tool_call_id": tool_call.id,
           "content": json.dumps(tool_result)
       })

       # Get final response
       final = litellm.completion(
           model="claude-sonnet-4-20250514",
           messages=messages,
           tools=tools
       )
       print(final.choices[0].message.content)
   ```

### Procedure 3: Streaming with LiteLLM

1. **Synchronous streaming**:
   ```python
   response = litellm.completion(
       model="claude-sonnet-4-20250514",
       messages=messages,
       stream=True,
       max_tokens=2048
   )

   for chunk in response:
       delta = chunk.choices[0].delta
       if delta.content:
           print(delta.content, end="", flush=True)
   ```

2. **Async streaming (for FastAPI)**:
   ```python
   response = await litellm.acompletion(
       model="claude-sonnet-4-20250514",
       messages=messages,
       stream=True,
       max_tokens=2048
   )

   async for chunk in response:
       delta = chunk.choices[0].delta
       if delta.content:
           yield delta.content
   ```

### Procedure 4: Using Ollama for Local Development

1. **Install Ollama**: Download from https://ollama.com/download

2. **Pull a model**:
   ```bash
   ollama pull mistral:7b      # 4.1GB, fast, good for dev
   ollama pull llama3.3:70b    # 40GB, high quality, needs 48GB RAM
   ```

3. **Use via LiteLLM** (recommended):
   ```python
   response = litellm.completion(
       model="ollama/mistral:7b",
       messages=[{"role": "user", "content": "Hello"}],
       api_base="http://localhost:11434"
   )
   ```

4. **Use via OpenAI SDK** (alternative):
   ```python
   client = openai.OpenAI(base_url="http://localhost:11434/v1", api_key="ollama")
   response = client.chat.completions.create(
       model="mistral:7b",
       messages=[{"role": "user", "content": "Hello"}]
   )
   ```

## Reference Tables

### LiteLLM Model Strings

| Provider | Model String | Notes |
|----------|-------------|-------|
| Anthropic | `claude-opus-4` | Most capable |
| Anthropic | `claude-sonnet-4-20250514` | Balanced |
| Anthropic | `claude-haiku-3.5` | Fast/cheap |
| OpenAI | `gpt-4o` | Multimodal |
| OpenAI | `gpt-4o-mini` | Cheapest |
| OpenAI | `o1` | Reasoning |
| Ollama | `ollama/mistral:7b` | Local, fast |
| Ollama | `ollama/llama3.3:70b` | Local, capable |

### Environment Variables

| Variable | Required | Provider | Example |
|----------|----------|----------|---------|
| `ANTHROPIC_API_KEY` | Yes (for Claude) | Anthropic | `sk-ant-api03-xxx` |
| `OPENAI_API_KEY` | Yes (for GPT) | OpenAI | `sk-xxx` |
| `OLLAMA_API_BASE` | No (default: localhost:11434) | Ollama | `http://localhost:11434` |
| `LITELLM_LOG` | No | LiteLLM | `DEBUG` for verbose logging |

### Common Error Codes

| Error | Provider | Cause | Fix |
|-------|----------|-------|-----|
| `AuthenticationError` | All | Invalid or missing API key | Check env var is set and key is valid |
| `RateLimitError` (429) | All | Too many requests | Implement backoff. Check tier limits. |
| `InvalidRequestError` (400) | All | Bad parameters (model, tokens) | Check model string. Reduce max_tokens. |
| `APIConnectionError` | Ollama | Ollama not running | Start Ollama: `ollama serve` |
| `ContextWindowExceeded` | All | Prompt too long | Count tokens before sending. Truncate. |

## Failure Modes

| Failure | Symptoms | Root Cause | Fix |
|---------|----------|------------|-----|
| Wrong model string | `NotFoundError: model not found` | Typo in model name or wrong provider prefix | Check exact model string in LiteLLM docs. Anthropic models don't need prefix; Ollama needs `ollama/` prefix. |
| API key not loaded | `AuthenticationError` on first request | Env var not set, or `.env` not loaded | Run `echo $ANTHROPIC_API_KEY` to verify. Add `python-dotenv` and call `load_dotenv()` at app startup. |
| Streaming breaks with tool calls | Partial tool call JSON, or missing tool_call_id | Tool calls in streaming mode need special handling | Accumulate tool call chunks before processing. Check `delta.tool_calls` exists before accessing. |
| Ollama timeout | Request hangs for >60 seconds | Model too large for available RAM, or first request loading model | Check RAM usage. Use smaller model. First request always slower (model loading). |
| LiteLLM version mismatch | Unexpected errors, missing features | LiteLLM updates frequently, API may change | Pin version in requirements.txt: `litellm==1.30.0`. Update deliberately. |
| Cost tracking miscount | Reported costs don't match provider dashboard | Token counting differences between LiteLLM and provider | Use provider's usage object from response. Cross-check with provider dashboard monthly. |

## Examples

### Example 1: Full Provider Setup with LiteLLM

```python
# app/services/llm.py
import litellm
from app.core.config import settings

# Configure LiteLLM
litellm.set_verbose = settings.debug

MODELS = {
    "fast": "claude-haiku-3.5",
    "standard": "claude-sonnet-4-20250514",
    "powerful": "claude-opus-4",
    "cheap": "gpt-4o-mini",
    "local": "ollama/mistral:7b"
}

async def complete(model_alias: str, messages: list, tools=None, **kwargs):
    model = MODELS.get(model_alias, model_alias)
    return await litellm.acompletion(
        model=model,
        messages=messages,
        tools=tools,
        temperature=kwargs.get("temperature", 0.0),
        max_tokens=kwargs.get("max_tokens", 2048),
        stream=kwargs.get("stream", True)
    )
```

**Usage**: `await complete("standard", messages, tools=my_tools, stream=True)`
