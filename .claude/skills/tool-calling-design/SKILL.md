---
name: tool-calling-design
description: Design reliable tool-calling schemas using JSON Schema, implement error handling for tool calls, compose multi-step tool sequences, and validate tool behavior in agent-first applications.
user-invocable: false
---

# Tool-Calling and Function Schema Design

## Purpose

Enable Claude to design action tool schemas that agents call reliably, implement robust error handling for tool invocations, and compose multi-step tool sequences. Covers JSON Schema design for LLM tool calling, parameter validation, error recovery, and schema testing.

## Key Rules

1. **Verb-Noun Tool Names**: Name every tool as `verb_noun` (e.g., `create_document`, `search_files`, `analyze_code`). This convention helps models understand tool purpose at selection time. Never use generic names like `process`, `handle`, or `execute`.

2. **Maximum 10 Tools Per Agent**: Tool selection accuracy drops below 85% with 12+ tools. Keep each agent under 10 tools. If you need more, split into specialist agents with a router.

3. **Required Parameters Only**: Minimize required parameters to 1-3 per tool. Use optional parameters with sensible defaults for everything else. More required parameters = more opportunities for the model to provide wrong values.

4. **Tool Descriptions Must Include "When to Use"**: Every tool description must contain: (a) what the tool does (1 sentence), (b) when to use it (trigger condition), (c) when NOT to use it (common misuse case). This reduces tool selection errors by 20-30%.

5. **Parameter Descriptions Must Include Format and Constraints**: Every parameter description must specify: data type, valid values/ranges, and an example. "The file path" is insufficient. "Absolute file path to the target document (e.g., '/docs/report.md'). Must exist and be readable." is sufficient.

6. **Error Responses Must Be Structured**: Tool error responses must return `{"error": "message", "code": "ERROR_CODE", "recoverable": true/false}`. The model uses this to decide whether to retry, try a different approach, or report the error.

7. **Idempotent Where Possible**: Design tools to be idempotent (calling twice with same params = same result). If a tool has side effects, document them clearly. Non-idempotent tools need confirmation checks.

8. **Validate Tool Schemas Against JSON Schema Draft 2020-12**: All tool schemas must be valid JSON Schema. Use `jsonschema` Python library to validate. Invalid schemas cause silent failures in provider APIs.

## Decision Framework

### Designing a Tool's Parameter Schema

```
For each parameter the tool needs:
|
+-- Is it always required for the tool to function?
|   +-- YES --> Mark as required. Add to "required" array.
|   +-- NO  --> Make it optional with a default value.
|
+-- What data type?
|   +-- Free text input from user --> type: "string"
|   +-- Selection from fixed options --> type: "string", enum: [options]
|   +-- Numeric value --> type: "number" or "integer", with minimum/maximum
|   +-- Boolean flag --> type: "boolean", default: false
|   +-- Structured data --> type: "object" with defined properties
|   +-- List of items --> type: "array" with items schema
|
+-- What constraints?
    +-- String length --> minLength, maxLength
    +-- Numeric range --> minimum, maximum
    +-- Pattern match --> pattern: "regex"
    +-- Fixed choices --> enum: ["option1", "option2"]
```

### Choosing Between One Complex Tool and Multiple Simple Tools

```
A capability requires multiple parameters and has conditional logic?
|
+-- All parameters are always needed together
|   --> One tool with all parameters
|       Example: create_user(name, email, role) -- all three always needed
|
+-- Parameters split into distinct phases
|   --> Separate tools for each phase
|       Example: search_products(query) then purchase_product(product_id, quantity)
|       This is a tool chain, not one big tool
|
+-- Some parameters only relevant for certain modes
|   --> One tool with optional parameters per mode
|       Example: export_data(format, options?) where options depends on format
|       Alternative: separate tools per mode if they diverge significantly
|
+-- Operation has a read-then-write pattern
    --> Two tools: one for read, one for write
        Example: get_document(id) then update_document(id, content)
        Never combine read+write into one tool (violates least privilege)
```

## Procedures

### Procedure 1: Design a Tool Schema from Requirements

1. **Name the tool** using verb_noun format:
   ```
   Requirement: "Search through project documents"
   Tool name: search_documents
   ```

2. **Write the description** with trigger and anti-trigger:
   ```json
   {
     "name": "search_documents",
     "description": "Search through project documents using semantic similarity. Use when the user asks a question about project content or needs to find specific information. Do NOT use for listing all documents (use list_documents instead) or for modifying document content."
   }
   ```

3. **Define parameters** with types, constraints, and examples:
   ```json
   {
     "parameters": {
       "type": "object",
       "properties": {
         "query": {
           "type": "string",
           "description": "Natural language search query (e.g., 'authentication flow for admin users'). Minimum 3 characters.",
           "minLength": 3,
           "maxLength": 500
         },
         "max_results": {
           "type": "integer",
           "description": "Maximum number of results to return. Default: 5. Range: 1-20.",
           "minimum": 1,
           "maximum": 20,
           "default": 5
         },
         "filter_type": {
           "type": "string",
           "description": "Filter results by document type. Options: 'all', 'markdown', 'code', 'config'.",
           "enum": ["all", "markdown", "code", "config"],
           "default": "all"
         }
       },
       "required": ["query"]
     }
   }
   ```

4. **Define the return schema** (for documentation and validation):
   ```json
   {
     "returns": {
       "type": "object",
       "properties": {
         "results": {
           "type": "array",
           "items": {
             "type": "object",
             "properties": {
               "document_id": { "type": "string" },
               "title": { "type": "string" },
               "snippet": { "type": "string" },
               "relevance_score": { "type": "number" }
             }
           }
         },
         "total_count": { "type": "integer" }
       }
     }
   }
   ```

5. **Validate the schema**:
   ```python
   import jsonschema
   jsonschema.validate(instance=example_params, schema=tool_schema["parameters"])
   ```

### Procedure 2: Implement Tool Error Handling

1. **Define error response format** (consistent across all tools):
   ```python
   class ToolError:
       def __init__(self, message: str, code: str, recoverable: bool, suggestion: str = ""):
           self.response = {
               "error": message,
               "code": code,
               "recoverable": recoverable,
               "suggestion": suggestion
           }
   ```

2. **Standard error codes**:

   | Code | Meaning | Recoverable | Agent Action |
   |------|---------|-------------|-------------|
   | `NOT_FOUND` | Resource does not exist | Yes | Try different ID or search first |
   | `PERMISSION_DENIED` | Agent lacks permission | No | Report to user, do not retry |
   | `INVALID_PARAMS` | Parameter validation failed | Yes | Fix parameters and retry |
   | `RATE_LIMITED` | Too many requests | Yes | Wait and retry after delay |
   | `INTERNAL_ERROR` | Unexpected server error | Yes (1 retry) | Retry once, then report |
   | `TIMEOUT` | Operation took too long | Yes | Retry with simpler input |
   | `CONFLICT` | Resource state conflict | Yes | Refresh state and retry |

3. **Implement retry logic** in the tool execution layer:
   ```python
   MAX_RETRIES = 2
   RETRY_DELAY = 1.0  # seconds

   async def execute_tool_with_retry(tool_name: str, params: dict) -> dict:
       for attempt in range(MAX_RETRIES + 1):
           result = await execute_tool(tool_name, params)
           if "error" not in result:
               return result
           if not result.get("recoverable", False):
               return result  # Non-recoverable, don't retry
           if attempt < MAX_RETRIES:
               await asyncio.sleep(RETRY_DELAY * (attempt + 1))
       return result  # Return last error after all retries exhausted
   ```

### Procedure 3: Generate Tool Schemas from Pydantic Models

1. **Define Pydantic models for tool parameters and returns**:
   ```python
   from pydantic import BaseModel, Field

   class SearchDocumentsParams(BaseModel):
       query: str = Field(
           ...,
           description="Natural language search query",
           min_length=3,
           max_length=500,
           examples=["authentication flow for admin users"]
       )
       max_results: int = Field(
           default=5,
           description="Maximum number of results to return",
           ge=1,
           le=20
       )
       filter_type: str = Field(
           default="all",
           description="Filter by document type",
           pattern="^(all|markdown|code|config)$"
       )
   ```

2. **Generate JSON Schema**:
   ```python
   schema = SearchDocumentsParams.model_json_schema()
   # Output: valid JSON Schema with all constraints, descriptions, and defaults
   ```

3. **Build the tool definition**:
   ```python
   tool_definition = {
       "name": "search_documents",
       "description": "Search through project documents using semantic similarity. "
                      "Use when the user asks about project content. "
                      "Do NOT use for listing all documents (use list_documents instead).",
       "input_schema": SearchDocumentsParams.model_json_schema()
   }
   ```

4. **Validate round-trip**: Parse example parameters through the Pydantic model to verify validation works:
   ```python
   params = SearchDocumentsParams(query="test query", max_results=5)
   assert params.query == "test query"
   ```

### Procedure 4: Compose Multi-Step Tool Sequences

1. **Identify the sequence**: Map the user goal to ordered tool calls:
   ```
   User goal: "Update the introduction of report.md"
   Step 1: get_document(id="report.md") -> current content
   Step 2: [agent reasons about what to change]
   Step 3: update_section(document_id="report.md", section="introduction", content="new text")
   Step 4: get_document(id="report.md") -> verify change applied
   ```

2. **Define data flow between steps**: Each tool's output provides inputs for the next:
   ```
   get_document.result.content -> agent reasoning -> update_section.params.content
   ```

3. **Add error branching**: If any step fails, define the recovery path:
   ```
   Step 1 fails (NOT_FOUND) -> report "document not found" to user
   Step 3 fails (CONFLICT) -> re-read document, re-analyze, retry update
   Step 4 result differs from expected -> report discrepancy to user
   ```

## Reference Tables

### Tool Schema Quick Reference (Anthropic Format)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Tool name in verb_noun format |
| `description` | string | Yes | What it does + when to use + when not to use |
| `input_schema` | object | Yes | JSON Schema for parameters |
| `input_schema.type` | string | Yes | Always "object" |
| `input_schema.properties` | object | Yes | Parameter definitions |
| `input_schema.required` | array | No | List of required parameter names |

### JSON Schema Type Reference

| Type | JSON Schema | Python Type | Common Constraints |
|------|------------|-------------|-------------------|
| Text | `"type": "string"` | `str` | `minLength`, `maxLength`, `pattern`, `enum` |
| Integer | `"type": "integer"` | `int` | `minimum`, `maximum`, `multipleOf` |
| Decimal | `"type": "number"` | `float` | `minimum`, `maximum`, `exclusiveMinimum` |
| Boolean | `"type": "boolean"` | `bool` | None |
| List | `"type": "array"` | `list` | `items`, `minItems`, `maxItems`, `uniqueItems` |
| Object | `"type": "object"` | `dict` | `properties`, `required`, `additionalProperties` |
| Enum | `"type": "string", "enum": [...]` | `Literal[...]` | Fixed set of valid values |

### Tool Naming Conventions

| Action Category | Verb Prefix | Examples |
|----------------|-------------|----------|
| Create | `create_` | `create_document`, `create_user`, `create_task` |
| Read | `get_`, `search_`, `list_` | `get_document`, `search_files`, `list_users` |
| Update | `update_`, `modify_` | `update_section`, `modify_settings` |
| Delete | `delete_`, `remove_` | `delete_document`, `remove_user` |
| Analyze | `analyze_`, `evaluate_` | `analyze_code`, `evaluate_quality` |
| Generate | `generate_`, `create_` | `generate_report`, `create_summary` |
| Execute | `run_`, `execute_` | `run_tests`, `execute_query` |

## Failure Modes

| Failure | Symptoms | Root Cause | Fix |
|---------|----------|------------|-----|
| Tool Selection Error | Agent calls wrong tool for the task, or calls no tool when one is needed | Tool descriptions are ambiguous, missing "when to use" guidance | Add explicit trigger conditions and "do NOT use when" to every tool description. Add 2-3 few-shot examples of correct tool selection. |
| Parameter Type Mismatch | Tool receives string "5" instead of integer 5, or object instead of array | JSON Schema types not enforced, or model generates wrong types | Add explicit type and format examples in parameter descriptions. Use Pydantic validation to coerce types. |
| Missing Required Parameter | Tool call fails because a required parameter is omitted | Model does not realize the parameter is required, or description does not explain why it is needed | Minimize required parameters (1-3). Add clear explanation of why each required parameter is needed. |
| Tool Call in Infinite Loop | Agent calls the same tool repeatedly without progress | No termination condition, or tool returns ambiguous success/failure | Add max_iterations limit (default: 5). Ensure tool results clearly indicate success or failure. Track call count per conversation. |
| Schema Validation Error | Provider API rejects tool schema at registration time | Invalid JSON Schema (wrong type, missing properties key, unsupported keyword) | Validate schema with `jsonschema` library before registration. Test with the specific provider API. |
| Overly Complex Tool | Tool has 8+ required parameters, model fills many incorrectly | Too many parameters for reliable model completion | Split into multiple simpler tools. Move parameters to optional with defaults. Use a two-step pattern: configure then execute. |

## Examples

### Example 1: Complete Tool Schema for a Code Review Agent

**Tools designed** (4 tools, single agent):

```json
[
  {
    "name": "analyze_code_quality",
    "description": "Analyze code quality metrics for a file. Use when the user asks for a code review or quality assessment. Do NOT use for finding specific bugs (use identify_bugs instead).",
    "input_schema": {
      "type": "object",
      "properties": {
        "file_path": {
          "type": "string",
          "description": "Path to the file to analyze (e.g., 'src/auth/login.py')"
        },
        "metrics": {
          "type": "array",
          "items": { "type": "string", "enum": ["complexity", "style", "patterns", "all"] },
          "description": "Which metrics to analyze. Default: ['all']",
          "default": ["all"]
        }
      },
      "required": ["file_path"]
    }
  },
  {
    "name": "identify_bugs",
    "description": "Scan a file for potential bugs and vulnerabilities. Use when the user asks to find bugs, issues, or security problems. Do NOT use for style or quality issues (use analyze_code_quality instead).",
    "input_schema": {
      "type": "object",
      "properties": {
        "file_path": {
          "type": "string",
          "description": "Path to the file to scan"
        },
        "severity_filter": {
          "type": "string",
          "enum": ["all", "critical", "high", "medium"],
          "description": "Minimum severity to report. Default: 'all'",
          "default": "all"
        }
      },
      "required": ["file_path"]
    }
  },
  {
    "name": "suggest_refactoring",
    "description": "Generate refactoring suggestions for a selected code region. Use when the user selects code and asks for improvement suggestions. Requires a code selection context from the user.",
    "input_schema": {
      "type": "object",
      "properties": {
        "file_path": { "type": "string", "description": "Path to the file" },
        "start_line": { "type": "integer", "description": "First line of the selection", "minimum": 1 },
        "end_line": { "type": "integer", "description": "Last line of the selection", "minimum": 1 }
      },
      "required": ["file_path", "start_line", "end_line"]
    }
  },
  {
    "name": "generate_tests",
    "description": "Generate unit test cases for a function or class. Use when the user asks for test generation. Do NOT use for running existing tests.",
    "input_schema": {
      "type": "object",
      "properties": {
        "file_path": { "type": "string", "description": "Path to the source file" },
        "function_name": { "type": "string", "description": "Name of the function or class to test" },
        "framework": {
          "type": "string",
          "enum": ["pytest", "vitest", "jest"],
          "description": "Test framework to use. Default: 'pytest'",
          "default": "pytest"
        }
      },
      "required": ["file_path", "function_name"]
    }
  }
]
```

**Validation**: All schemas pass `jsonschema` validation. Tool count = 4 (well under 10). Each description has "use when" and "do NOT use when". Required parameters are minimal (1-3 each).
