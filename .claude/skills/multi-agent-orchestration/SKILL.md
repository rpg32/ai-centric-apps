---
name: multi-agent-orchestration
description: Patterns for coordinating multiple AI agents using LangGraph state machines, supervisor/worker patterns, handoff protocols, and shared state management.
user-invocable: false
---

# Multi-Agent Orchestration

## Purpose

Enable Claude to design and implement systems where multiple AI agents coordinate to accomplish complex tasks. Covers orchestration patterns (supervisor, pipeline, state machine), framework selection (LangGraph, CrewAI, AutoGen), handoff protocols, and shared state management.

## Key Rules

1. **Every Multi-Agent System Needs an Entry Point Agent**: Whether a router, supervisor, or classifier, one agent must receive every user request first and decide which specialist handles it. Direct user-to-specialist routing bypasses orchestration and leads to role confusion.

2. **Delegation Depth Limit: 3**: An agent can delegate to another agent, which can delegate once more, for a maximum chain of 3. Beyond 3 levels, latency exceeds 30 seconds and error propagation becomes unmanageable. If you need deeper chains, restructure the architecture.

3. **Explicit Handoff Protocol**: When Agent A passes work to Agent B, the handoff must include: (a) task description, (b) relevant context (not full conversation), (c) expected output format, (d) return address (who gets the result). Implicit "figure it out" handoffs cause role confusion.

4. **No Shared Mutable State Between Agents**: Agents must not modify a shared object simultaneously. Use LangGraph's state management (reducer functions) or message-passing patterns. If two agents need to update the same data, serialize their access through the supervisor.

5. **Each Agent Gets Its Own System Prompt**: Never share system prompts between agents. Each agent's prompt defines its unique role, tools, and constraints. Shared prompts lead to role confusion and overlapping actions.

6. **Maximum 8 Agents in a Single System**: Systems with >8 agents have exponentially more handoff paths and become difficult to debug. If you need more, group agents into subsystems with a subsystem supervisor.

## Decision Framework

### Choosing an Orchestration Pattern

```
What is the relationship between agents?
|
+-- One agent classifies, others execute
|   --> Supervisor/Router pattern
|       Entry agent classifies intent -> routes to specialist
|       Specialist executes -> returns result to supervisor
|       Supervisor formats and returns to user
|       Best for: clearly separable domains, 2-5 specialists
|
+-- Agents must work in sequence (output of A feeds B)
|   --> Pipeline/Chain pattern
|       Agent A -> result -> Agent B -> result -> Agent C
|       No branching, linear flow
|       Best for: multi-step transformations, document processing
|
+-- Agents need to collaborate and iterate
|   --> Conversation/Debate pattern
|       Agents exchange messages until consensus or limit
|       Best for: complex analysis, multi-perspective review
|       Framework: AutoGen group chat
|
+-- Complex routing with conditions, loops, and branches
|   --> State Machine pattern (LangGraph)
|       Graph with nodes (agents), edges (transitions), state
|       Conditional edges based on agent output
|       Best for: complex workflows, human-in-the-loop
|
+-- Agents work independently on parallel subtasks
    --> Fan-out/Fan-in pattern
        Supervisor splits task -> parallel agents -> collect results
        Best for: independent subtasks, map-reduce
```

### Choosing a Framework

```
Which orchestration pattern was selected?
|
+-- Supervisor/Router, Pipeline, or Fan-out
|   |
|   +-- Need fine-grained control over flow? --> LangGraph
|   +-- Need role-based collaboration?       --> CrewAI
|   +-- Simple routing only?                 --> Custom (direct SDK)
|
+-- Conversation/Debate
|   --> AutoGen (group chat pattern)
|
+-- State Machine with complex conditions
|   --> LangGraph (only option for complex state machines)
|
+-- Any pattern in TypeScript
    --> LangGraph.js or custom with Vercel AI SDK
```

## Procedures

### Procedure 1: Implement a Supervisor/Router with LangGraph

1. **Define the state schema**:
   ```python
   from typing import Annotated, TypedDict, Literal
   from langgraph.graph import StateGraph, END
   from langgraph.graph.message import add_messages

   class AgentState(TypedDict):
       messages: Annotated[list, add_messages]
       current_agent: str
       task_result: dict | None
   ```

2. **Create the router node**:
   ```python
   async def router_node(state: AgentState) -> AgentState:
       """Classify user intent and route to specialist."""
       response = await litellm.acompletion(
           model="claude-haiku-3.5",  # Fast, cheap for classification
           messages=[
               {"role": "system", "content": ROUTER_PROMPT},
               *state["messages"]
           ],
           temperature=0.0,
           max_tokens=100
       )

       # Parse routing decision
       route = parse_route(response)  # Returns: "analyst", "editor", "search"
       return {"current_agent": route}
   ```

3. **Create specialist nodes**:
   ```python
   async def analyst_node(state: AgentState) -> AgentState:
       """Document analysis specialist."""
       response = await litellm.acompletion(
           model="claude-sonnet-4-20250514",
           messages=[
               {"role": "system", "content": ANALYST_PROMPT},
               *state["messages"]
           ],
           tools=ANALYST_TOOLS,
           temperature=0.1
       )
       return {"messages": [response], "task_result": parse_result(response)}
   ```

4. **Build the graph**:
   ```python
   graph = StateGraph(AgentState)

   # Add nodes
   graph.add_node("router", router_node)
   graph.add_node("analyst", analyst_node)
   graph.add_node("editor", editor_node)
   graph.add_node("search", search_node)

   # Add edges
   graph.set_entry_point("router")
   graph.add_conditional_edges(
       "router",
       lambda state: state["current_agent"],
       {
           "analyst": "analyst",
           "editor": "editor",
           "search": "search"
       }
   )
   graph.add_edge("analyst", END)
   graph.add_edge("editor", END)
   graph.add_edge("search", END)

   # Compile
   app = graph.compile()
   ```

5. **Invoke**:
   ```python
   result = await app.ainvoke({
       "messages": [{"role": "user", "content": user_message}],
       "current_agent": "",
       "task_result": None
   })
   ```

### Procedure 2: Define Handoff Protocol

1. **Create a handoff message format**:
   ```python
   class AgentHandoff:
       def __init__(self, from_agent: str, to_agent: str, task: str,
                    context: dict, expected_output: str):
           self.message = {
               "handoff_from": from_agent,
               "handoff_to": to_agent,
               "task": task,
               "context": context,  # Only relevant data, not full history
               "expected_output_format": expected_output,
               "timestamp": datetime.utcnow().isoformat()
           }
   ```

2. **Implement context summarization for handoffs**:
   ```python
   def prepare_handoff_context(full_messages: list, max_tokens: int = 2000) -> dict:
       """Summarize conversation context for handoff, keeping it under budget."""
       # Keep last 3 messages verbatim
       recent = full_messages[-3:]

       # Summarize older messages if they exist
       if len(full_messages) > 3:
           older = full_messages[:-3]
           summary = summarize_messages(older)  # LLM call to summarize
       else:
           summary = ""

       return {
           "summary": summary,
           "recent_messages": recent
       }
   ```

3. **Add handoff validation**:
   ```python
   def validate_handoff(handoff: dict, agent_registry: dict) -> bool:
       """Verify handoff is valid before executing."""
       # Check target agent exists
       if handoff["handoff_to"] not in agent_registry:
           raise ValueError(f"Unknown target agent: {handoff['handoff_to']}")

       # Check delegation depth
       if handoff.get("depth", 0) >= 3:
           raise ValueError("Delegation depth limit (3) exceeded")

       # Check target agent can handle the task
       target = agent_registry[handoff["handoff_to"]]
       if handoff["task"] not in target["capabilities"]:
           raise ValueError(f"Agent {handoff['handoff_to']} cannot handle task: {handoff['task']}")

       return True
   ```

## Reference Tables

### Orchestration Pattern Comparison

| Pattern | Agents | Latency | Complexity | Framework | Best For |
|---------|--------|---------|------------|-----------|----------|
| Supervisor/Router | 3-6 | 2-8s | Medium | LangGraph, Custom | Clear domain separation |
| Pipeline/Chain | 2-4 | 5-20s (sequential) | Low | LangGraph, LangChain | Sequential transformations |
| Conversation | 2-4 | 10-30s | High | AutoGen | Complex analysis |
| State Machine | 3-8 | 5-30s | High | LangGraph | Complex workflows |
| Fan-out/Fan-in | 3-8 | 3-10s (parallel) | Medium | LangGraph | Independent subtasks |

### Agent Role Templates

| Role | Purpose | Model Recommendation | Tools |
|------|---------|---------------------|-------|
| Router/Classifier | Classify intent, route to specialist | claude-haiku (fast, cheap) | None (classification only) |
| Supervisor | Coordinate specialists, merge results | claude-sonnet (balanced) | Delegation tools |
| Specialist | Execute domain-specific tasks | claude-sonnet or opus | Domain-specific tools |
| Critic/Reviewer | Evaluate output quality | claude-sonnet | Evaluation tools |
| Summarizer | Condense and format results | claude-haiku | None |

### LangGraph State Management

| Reducer | Purpose | Example |
|---------|---------|---------|
| `add_messages` | Append messages to list | Conversation history |
| `operator.add` | Concatenate lists | Collecting results from parallel agents |
| Custom reducer | Merge or overwrite | `lambda old, new: new if new else old` |

## Failure Modes

| Failure | Symptoms | Root Cause | Fix |
|---------|----------|------------|-----|
| Agent Role Confusion | Agents produce conflicting outputs, tasks fall between agents | Overlapping responsibilities, shared system prompts, ambiguous routing | Assign each tool to exactly one agent. Write distinct system prompts. Add explicit "you do NOT" lists. Test with ambiguous inputs. |
| Infinite Delegation Loop | Agent A delegates to B, B delegates back to A, latency spikes | Missing delegation depth limit, circular dependency in routing logic | Add depth counter to handoffs. Max depth = 3. Log and break loops. Add cycle detection to graph. |
| Supervisor Bottleneck | All requests queue behind the supervisor, latency increases linearly with load | Supervisor uses expensive model (opus), or does too much processing | Use cheap/fast model for routing (haiku). Router should only classify, not process. Parallelize specialist calls. |
| State Corruption | Agent sees stale data, conflicting updates from parallel agents | Shared mutable state without proper synchronization | Use LangGraph reducers. Serialize access through supervisor. Use immutable state snapshots for parallel fan-out. |
| Context Lost in Handoff | Specialist agent gives irrelevant answers because it lacks context from earlier conversation | Handoff includes only task description, not conversation context | Include summarized context in handoff. Keep last 3 messages verbatim. Set context budget per handoff (2000 tokens). |
| Latency Spiral | Multi-agent response takes >30 seconds, users abandon requests | Sequential agent chain too long, or agents make multiple LLM calls each | Parallelize independent agents. Use faster models for non-critical steps. Limit chain to 3 agents max. Stream partial results. |

## Examples

### Example 1: Document Processing Pipeline (3 Agents)

**Architecture**: Pipeline pattern -- Analyst -> Editor -> Reviewer

```python
# Agent 1: Analyst (extracts key information)
# Agent 2: Editor (rewrites based on analysis)
# Agent 3: Reviewer (quality check before returning to user)

graph = StateGraph(DocState)
graph.add_node("analyst", analyst_node)
graph.add_node("editor", editor_node)
graph.add_node("reviewer", reviewer_node)

graph.set_entry_point("analyst")
graph.add_edge("analyst", "editor")
graph.add_edge("editor", "reviewer")

# Reviewer can loop back to editor if quality is low
graph.add_conditional_edges(
    "reviewer",
    lambda state: "editor" if state["quality_score"] < 0.8 else "end",
    {"editor": "editor", "end": END}
)

app = graph.compile()
```

**Latency**: Analyst (3s) + Editor (4s) + Reviewer (2s) = 9s total. Within 15s target.

**Handoff context**: Analyst passes structured findings (not full document) to Editor. Editor passes rewritten text to Reviewer. Reviewer returns quality score + specific issues if any.
