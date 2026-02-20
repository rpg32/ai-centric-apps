---
name: agent-first-architecture
description: Core paradigm for designing applications where AI agents are primary actors and the UI serves as a context facilitator, including the tool inversion principle, agent decomposition, and bidirectional context flow.
user-invocable: false
---

# Agent-First Architecture

## Purpose

Enable Claude to design and build applications where AI agents are the foundational architecture -- not bolted onto existing software, but the core around which the entire application is constructed. The UI serves as a context facilitator mediating between users and agents.

## Key Rules

1. **Tool Inversion Principle**: The user gets context tools (select, highlight, annotate, constrain). The agent gets action tools (create, modify, delete, execute). Never give users direct action tools in an agent-first app. Never give agents context-gathering tools that bypass the user.

2. **Context Facilitator, Not Traditional UI**: The UI exists to (a) display information the user can interact with to provide structured context, and (b) render agent outputs back to the user. It does NOT exist to provide direct manipulation controls.

3. **Agent-First Scoping**: When defining requirements, ask "What does the agent need to do?" and "What context does the user need to provide to guide the agent?" -- NOT "What features does the user need?"

4. **Maximum 10 Action Tools Per Agent**: A single agent with >10 tools shows declining tool-selection accuracy (drops below 85% at 12+ tools). Decompose into specialists when approaching this limit.

5. **Context Window Token Budget**: Reserve at least 30% of the model's context window for the agent's reasoning and response. If system prompt + RAG results + conversation history + context tool data exceeds 70% of the window, implement context prioritization.

6. **Bidirectional Context Flow Is Mandatory**: Every agent interaction must have both directions: user provides structured context (via context tools) AND agent provides structured output (rendered in context windows). One-directional flows indicate a design flaw.

7. **Provider Abstraction Layer**: Never call a single LLM provider's API directly from application code. All LLM calls go through an abstraction layer (LiteLLM, custom adapter, or Vercel AI SDK) that enables provider switching, fallback, and cost tracking.

8. **Security Architecture at Design Time**: The two catastrophic failure modes (prompt injection, data leakage) have architectural roots. Security mechanisms (input sanitization, output filtering, tool permission scoping) must be designed in Stage 02, not bolted on in Stage 06.

## Decision Framework

### Single-Agent vs. Multi-Agent

```
How many distinct capability domains does the application cover?
|
+-- 1 domain, <= 8 action tools
|   --> Single agent
|       Use when: one coherent skill set, simple orchestration
|       Example: code review tool (reads files, analyzes, reports)
|
+-- 1 domain, 9-15 action tools
|   --> Single agent with tool groups OR 2 specialist agents
|       Split criterion: do tools naturally cluster into 2 groups?
|       YES --> 2 specialists with a router
|       NO  --> single agent, optimize tool descriptions
|
+-- 2-4 distinct domains
|   --> Multi-agent with supervisor/router
|       Use when: agents need different model capabilities,
|       different tool sets, or different system prompts
|       Pattern: supervisor agent delegates to specialists
|
+-- 5+ distinct domains or complex workflows
    --> Multi-agent with state machine (LangGraph)
        Use when: complex branching, conditional routing,
        human-in-the-loop approvals, long-running workflows
```

### Choosing an Orchestration Pattern

```
Multi-agent system needed?
|
+-- Agents work independently on separate tasks
|   --> Parallel dispatch pattern
|       Supervisor sends tasks, collects results
|       Framework: LangGraph (parallel nodes) or custom
|
+-- Agents must pass work sequentially (pipeline)
|   --> Chain/pipeline pattern
|       Output of Agent A feeds into Agent B
|       Framework: LangGraph (linear graph) or LangChain
|
+-- Agents need to negotiate or collaborate
|   --> Conversation pattern
|       Agents exchange messages until consensus
|       Framework: AutoGen (group chat) or CrewAI (crew)
|
+-- Complex routing with conditions and loops
    --> State machine pattern
        Explicit nodes, edges, and conditions
        Framework: LangGraph (graph with conditional edges)
```

### Choosing an Agent Framework

```
What is the primary implementation language?
|
+-- Python
|   |
|   +-- Need explicit state machine control? --> LangGraph
|   +-- Need role-based team collaboration?  --> CrewAI
|   +-- Need structured output validation?   --> PydanticAI
|   +-- Simple single-agent with tools?      --> Direct SDK (anthropic/openai)
|   +-- Need conversation-based multi-agent? --> AutoGen
|
+-- TypeScript/JavaScript
|   |
|   +-- Using Next.js/React?        --> Vercel AI SDK
|   +-- Need LangChain ecosystem?   --> LangChain.js / LangGraph.js
|   +-- Simple single-agent?        --> Direct SDK (@anthropic-ai/sdk)
|
+-- Either language
    --> LiteLLM for provider abstraction regardless of framework choice
```

## Procedures

### Procedure 1: Design an Agent-First Application from Requirements

1. **Extract agent capabilities**: For each user requirement, translate it into an agent action. "User needs to edit documents" becomes "Agent can modify document content, insert sections, rewrite paragraphs."

2. **Define action tools**: For each agent capability, define one or more action tools with JSON Schema parameters. Name tools with verb-noun format: `create_document`, `modify_section`, `analyze_content`. Maximum 10 per agent.

3. **Define context tools**: For each action the agent takes, determine what context the user needs to provide. "Modify section" requires the user to select which section (a context tool). Map every action tool to at least one context tool.

4. **Validate bidirectional flow**: For each user goal, trace: user provides context (via context tool) -> agent receives structured data -> agent calls action tool -> result rendered in context window for user. If any link is missing, add it.

5. **Assess agent count**: Count total action tools. If >10, group tools by domain affinity. Each group becomes a specialist agent. Add a supervisor/router agent if >1 specialist.

6. **Select models**: Assign each agent a model based on task complexity:
   - Simple classification/routing: `claude-haiku` or `gpt-4o-mini` (fast, cheap)
   - Standard reasoning and tool use: `claude-sonnet` or `gpt-4o` (balanced)
   - Complex reasoning, long context: `claude-opus` or `o1` (powerful, expensive)

7. **Design security boundaries**: For each agent, define: allowed tools (whitelist), maximum token budget per request, output filtering rules, and input sanitization requirements.

### Procedure 2: Validate an Agent Architecture

1. **Tool count check**: No agent has >10 action tools. Flag and decompose if violated.

2. **Role overlap check**: List every agent's action tools. No tool appears in >1 agent's list. If it does, assign it to one agent and have others delegate.

3. **Context coverage check**: For every action tool, verify at least one context tool provides the required input data. If an action tool receives no user context, either it is autonomous (document why) or there is a context gap.

4. **Token budget check**: For each agent, estimate: system prompt tokens + average RAG results + average context tool data + conversation history. Total must be <70% of model context window.
   - claude-sonnet-4-20250514: 200K tokens, budget ceiling = 140K
   - gpt-4o: 128K tokens, budget ceiling = 89K
   - Local models (Llama 3): 8K-128K depending on model, budget accordingly

5. **Security check**: Every agent must have: (a) tool permission whitelist, (b) output filtering for sensitive data patterns, (c) input sanitization for prompt injection patterns. Missing any = blocking finding.

6. **Latency check**: Count maximum sequential LLM calls for the longest user interaction path. Each call adds 1-5s latency. If total >15s for single-agent or >30s for multi-agent, redesign to parallelize or use streaming.

### Procedure 3: Implement Tool Inversion in a Context Window

1. **Identify the information** displayed in the context window (e.g., a document, a code file, a 3D model, a data table).

2. **Design context tools** for that window. Common patterns:
   - **Selection**: User clicks/highlights a portion -> structured selection data sent to agent
   - **Annotation**: User adds a comment or tag -> annotation text + location sent to agent
   - **Constraint**: User sets a parameter or filter -> constraint value sent to agent
   - **Focus**: User navigates to a specific area -> viewport/focus area sent to agent

3. **Define the structured data format** each context tool produces. Use JSON. Example for a text selection:
   ```json
   {
     "context_type": "text_selection",
     "source": "document_id_123",
     "selected_text": "The mitochondria is the powerhouse...",
     "start_offset": 450,
     "end_offset": 495,
     "surrounding_context": "...previous paragraph... [SELECTED] ...next paragraph..."
   }
   ```

4. **Wire context data to the agent prompt**: Context tool output is injected into the agent's prompt as structured data in a clearly delimited section (e.g., `<user_context>...</user_context>`).

5. **Design the agent output rendering**: Define how the agent's response maps back to the context window. Common patterns:
   - **Inline annotation**: Agent output appears as annotations in the same context window
   - **Side panel**: Agent output renders in an adjacent panel
   - **Replacement**: Agent output replaces selected content (with undo)
   - **New window**: Agent output opens a new context window

## Reference Tables

### Agent Complexity Tiers

| Tier | Action Tools | Model Recommendation | Context Window Budget | Example |
|------|-------------|---------------------|----------------------|---------|
| Simple | 1-3 | claude-haiku / gpt-4o-mini | 4K-8K tokens | Code reviewer, Q&A bot |
| Standard | 4-8 | claude-sonnet / gpt-4o | 16K-64K tokens | Writing assistant, data analyst |
| Complex | 9-10 | claude-opus / o1 | 64K-140K tokens | Domain specialist, multi-step planner |
| Decompose | >10 | Split into specialists | N/A | Sign of monolithic anti-pattern |

### Context Tool Patterns

| Pattern | User Action | Structured Output | Use When |
|---------|------------|-------------------|----------|
| Selection | Click/highlight | `{type, source, content, range}` | User chooses what to act on |
| Annotation | Add note/tag | `{type, source, text, location}` | User provides guidance/instructions |
| Constraint | Set slider/dropdown | `{type, param, value, unit}` | User bounds the agent's action space |
| Focus | Navigate/zoom | `{type, viewport, center, zoom_level}` | User directs agent attention |
| Upload | Drag-drop file | `{type, filename, content_summary, size_bytes}` | User provides external data |
| Toggle | Enable/disable option | `{type, option, enabled}` | User controls agent behavior flags |

### Model Selection Quick Reference

| Provider | Model | Strengths | Cost (per 1M tokens) | Context Window |
|----------|-------|-----------|----------------------|----------------|
| Anthropic | claude-opus-4 | Complex reasoning, long context | ~$15 input / ~$75 output | 200K |
| Anthropic | claude-sonnet-4 | Balanced performance/cost | ~$3 input / ~$15 output | 200K |
| Anthropic | claude-haiku-3.5 | Speed, simple tasks | ~$0.80 input / ~$4 output | 200K |
| OpenAI | gpt-4o | Multimodal, fast | ~$2.50 input / ~$10 output | 128K |
| OpenAI | gpt-4o-mini | Cheap, fast, simple tasks | ~$0.15 input / ~$0.60 output | 128K |
| OpenAI | o1 | Complex reasoning chains | ~$15 input / ~$60 output | 200K |
| Ollama | llama3.3:70b | Local, private, zero cost | $0 (hardware cost) | 128K |
| Ollama | mistral:7b | Local, fast, lightweight | $0 (hardware cost) | 32K |

### Project Type to Architecture Mapping

| Project Type | Agents | Orchestration | Primary Framework | Context Interface |
|-------------|--------|--------------|------------------|-------------------|
| Single-Agent CLI | 1 | None | Direct SDK | Terminal stdin/stdout |
| Simple Chat Web | 1 | None | Vercel AI SDK or FastAPI | Chat + 1-2 context windows |
| Multi-Agent Web | 2-4 | Supervisor/Router | LangGraph + FastAPI | Multiple context windows |
| Desktop Agent | 1-3 | Chain or Parallel | Tauri/Electron + Python backend | OS-level context + panels |
| Domain-Specific | 3-6 | State Machine | LangGraph | Rich interactive windows |
| Multi-Platform | 4-8 | State Machine | LangGraph + platform adapters | Platform-specific interfaces |

## Failure Modes

| Failure | Symptoms | Root Cause | Fix |
|---------|----------|------------|-----|
| Monolithic Agent | Tool selection accuracy <85%, context window near capacity, slow responses | Single agent given too many responsibilities and tools (>10) | Decompose into specialists. Add supervisor/router. Target <=8 tools per specialist. |
| Agent Role Confusion | Agents give conflicting answers, tasks fall through gaps, circular delegation | Overlapping responsibilities, ambiguous tool assignments | Assign each tool to exactly one agent. Write explicit role boundaries in system prompts. Add delegation depth limit of 3. |
| Context Starvation | Agent gives generic/vague responses despite user interaction with context windows | Context tools do not extract useful structured data from user interactions | Redesign context tools to produce richer structured JSON. Add context preview feature. Test with real user interactions. |
| Context Overload | Token limit errors, agent ignores recent instructions, incoherent responses | Too much context stuffed into prompt from RAG + history + context tools | Implement context prioritization. Cap RAG results at 5 chunks (2K tokens each). Summarize history beyond 10 turns. |
| Provider Lock-in | Cannot switch models when one provider has outage, cannot A/B test providers | Direct API calls throughout codebase without abstraction layer | Introduce LiteLLM or custom abstraction. Refactor all direct API calls to go through abstraction. |
| Tool Schema Mismatch | Runtime errors on tool calls, silent data corruption, unexpected agent behavior | JSON Schema definition does not match actual tool implementation | Generate schemas from code (Pydantic models) or vice versa. Add schema validation tests in CI. |
| One-Way Context Flow | Users provide input but never see structured agent output, OR agent acts without user context | Missing half of bidirectional context design | Audit every agent interaction. Ensure both: user->agent context path AND agent->user rendering path exist. |

## Examples

### Example 1: Designing a Code Review Agent Application

**Scenario**: Build a web app where an AI agent reviews code files and suggests improvements.

**Step 1 - Agent capabilities**:
- Analyze code quality (complexity, style, patterns)
- Suggest refactoring improvements
- Identify potential bugs
- Generate test suggestions

**Step 2 - Action tools** (4 total):
- `analyze_code_quality(file_path, metrics)` -> quality report
- `suggest_refactoring(file_path, selection_range)` -> refactoring suggestions
- `identify_bugs(file_path)` -> bug report with severity
- `generate_test_cases(file_path, function_name)` -> test code

**Step 3 - Context tools**:
- Code file viewer with line selection (context tool: selection)
- Severity filter dropdown (context tool: constraint)
- File tree navigator (context tool: focus)

**Step 4 - Bidirectional flow**:
- User selects code lines -> `{type: "code_selection", file: "app.py", lines: [45, 62]}` -> agent calls `suggest_refactoring` -> suggestion rendered as inline annotation in code viewer

**Step 5 - Agent count**: 4 tools, single agent, no decomposition needed.

**Step 6 - Model**: claude-sonnet (standard reasoning, code analysis).

**Step 7 - Security**: Tool whitelist = read-only tools only (no code modification). Output filter = no secrets/API keys in suggestions. Input sanitization = reject prompts containing instruction override patterns.

### Example 2: Multi-Agent Project Management Tool

**Scenario**: Web app with planning agent and execution tracking agent.

**Architecture**:
- **Planning Agent** (6 tools): create_milestone, create_task, estimate_effort, assign_priority, decompose_task, generate_timeline
- **Tracking Agent** (5 tools): update_status, log_progress, generate_report, detect_blockers, calculate_velocity
- **Router Agent** (0 action tools): classifies user intent and delegates to the appropriate specialist

**Context Interface**:
- Timeline view (context tool: selection on milestones, focus on date ranges)
- Task board (context tool: drag-drop status changes as constraints)
- Report panel (context tool: date range selector, metric toggles)

**Orchestration**: Supervisor pattern via LangGraph. Router node classifies intent, edges route to specialist nodes.
