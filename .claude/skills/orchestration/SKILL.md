---
name: orchestration
description: >
  How to operate agents — dispatch prompts, permissions, monitoring, failure
  recovery, parallel patterns, convergent multi-agent review, and agent teams
  for the AI-Centric Apps orchestrator.
globs:
  - ".claude/CLAUDE.md"
  - ".claude/commands/*.md"
user-invocable: false
---

# Orchestration Skill

## Purpose

This skill governs how the AI-Centric Apps orchestrator dispatches work to
subagents, manages permissions, coordinates parallel work, handles failures,
and processes results. The goal is to keep the orchestrator's context clean
and focused on coordination while subagents handle domain-heavy work in
isolation.

For agent **definition** guidance (YAML format, fields, skills, migration),
see the `agent-dispatch` skill. For **context window** management (clearing,
budgets, compaction), see the `context-management` skill.

---

## 1. Core Principle: Protect the Orchestrator's Context

The orchestrator's context window is a shared resource across the entire
session. Every tool result, file read, and agent output that enters the
orchestrator's context reduces capacity for future coordination.

**Rules:**
- Never read large domain artifacts in the orchestrator — delegate to a subagent
- Never run verbose commands (test suites, builds, linters) in the orchestrator — delegate to a subagent
- When a subagent returns results, summarize them concisely before presenting to the user
- Use subagents for any exploration that might require >3 tool calls
- The orchestrator should primarily use: project-state.json reads, registry reads, git status, and lightweight coordination commands

**What belongs in the orchestrator's context:**
- Project state (project-state.json — small JSON)
- User intent and decisions
- Subagent result summaries
- Gate review checklists (short, structured)
- Error messages and next-step decisions

**What does NOT belong in the orchestrator's context:**
- Full source code files (delegate reading src/ to the implementation agent)
- Prompt library contents (delegate to the integration agent)
- Test suite output (delegate to the evaluation agent)
- RAG configuration details (delegate to the integration or context-design agent)
- Agent architecture documents (delegate to the architecture agent)
- Security audit reports (delegate to the evaluation agent)
- Build logs and deployment output (delegate to the deployment agent)

---

## 2. Dispatch Decision Tree

When the user requests work, decide how to handle it:

```
Is the task a quick coordination action?
  (state check, git commit, registry update, user question)
  → YES: Handle directly in orchestrator
  → NO: Continue...

Does the task match a pipeline stage?
  (scoping, agent-architecture, context-design, ai-integration, implementation, evaluation, deployment)
  → YES: Dispatch to the stage's subagent
  → NO: Continue...

Is the task self-contained and focused?
  (read a file, run a search, analyze something specific)
  → YES: Dispatch to a single subagent (Explore for read-only, general-purpose for actions)
  → NO: Continue...

Does the task have independent parallel subtasks?
  (multiple areas to investigate, multiple files to modify independently)
  → YES: Dispatch multiple subagents in parallel (§3.3)
  → NO: Continue...

Would competing perspectives improve the outcome?
  (design review, architecture decision, quality audit)
  → YES: Use convergent multi-agent pattern (§3.5)
  → NO: Dispatch a single subagent
```

---

## 3. Dispatch Patterns

### 3.1 Single Foreground Dispatch

**Use when:** The orchestrator needs the result before it can proceed.

**Pattern:** Dispatch one subagent, wait for result, then act on it.

**Examples:**
- Running a gate review (need pass/fail before advancing state)
- Reading project artifacts to answer a user question
- Executing a pipeline stage that the user is actively watching

**Key rule:** Give the subagent a complete, self-contained prompt with all
necessary context. The subagent does NOT inherit the orchestrator's conversation
history — it starts fresh with only its system prompt, preloaded skills, and
the dispatch prompt.

### 3.2 Single Background Dispatch

**Use when:** The work is independent and the orchestrator can do other things
while it runs.

**Pattern:** Dispatch with `run_in_background: true`, continue other work,
check results later with `TaskOutput`.

**Examples:**
- Running validation checks while the user discusses design decisions
- Generating output files while reviewing another stage
- Long-running analysis tasks

**Constraints of background dispatch:**
- Background subagents **cannot ask clarifying questions** — the `AskUserQuestion` tool fails silently. Provide ALL necessary context upfront.
- Background subagents **auto-deny all permission prompts**. If the agent needs Bash, Write, or MCP tools that require user approval, either: (a) run in foreground instead, or (b) pre-approve the permissions in the session first.
- **MCP tools are NOT available** in background subagents.
- Background agents cannot use `EnterPlanMode` or interact with the user in any way.

### 3.3 Parallel Dispatch (Multiple Subagents)

**Use when:** The task decomposes into independent subtasks that don't depend
on each other's results.

**Pattern:** Dispatch multiple subagents in a single message (multiple Task
tool calls in one response). Each gets a distinct, non-overlapping scope.

**Examples:**
- Agent architecture review + security audit in parallel (different review lenses on the same artifacts)
- Generating prompt library + RAG configuration simultaneously (independent integration artifacts)
- Running unit tests + linting + type checking in parallel (independent quality checks)

**Critical rules for parallel dispatch:**
1. **No overlapping file writes** — two agents writing the same file causes data loss
2. **No dependent results** — if Agent B needs Agent A's output, dispatch sequentially
3. **Clear scope boundaries** — each agent's prompt must define exactly what it owns
4. **Minimize result volume** — request summaries, not raw data

### 3.4 Sequential Chain

**Use when:** Later work depends on earlier results.

**Pattern:** Dispatch Agent A → wait for result → extract key facts → use
those facts to inform Agent B's prompt → dispatch Agent B.

**Examples:**
- Analysis agent identifies issues → fix agent resolves them
- Research agent gathers requirements → implementation agent builds from them
- Cleanup agent prepares state → action agent operates on clean state

**Key rule:** Extract only the essential information from Agent A's result
to include in Agent B's prompt. Don't forward raw output — summarize.

### 3.5 Convergent Multi-Agent Review

**Use when:** A decision or artifact benefits from multiple independent
perspectives that are then synthesized.

**Pattern:**
1. Dispatch N subagents in parallel, each with a different review lens
2. Each agent independently analyzes the same artifact(s)
3. Collect all results
4. Synthesize: identify agreements, disagreements, and unique findings
5. Present the synthesis to the user for decision-making

**When to use convergent review:**
- Design decisions with competing concerns (performance vs simplicity)
- Quality audits where domain expertise spans multiple specialties
- Architecture reviews before committing to an approach
- Any decision where a single perspective may miss important tradeoffs

**Rules:**
- Each agent gets the SAME artifact references but a DIFFERENT review prompt
- Agents must not know about each other — independence prevents anchoring
- The orchestrator synthesizes — never forward one agent's output to another
- Minimum 2 agents, maximum 4 (beyond 4, diminishing returns vs token cost)
- Label each agent's lens clearly in the dispatch prompt so its focus is sharp

---

## 4. Permissions Management

### 4.1 Permission Modes

Subagents can declare a `permissionMode` in their YAML frontmatter:

| Mode | Behavior | Use Case |
|------|----------|----------|
| `default` | Inherits session permissions; prompts user for unapproved actions | Most pipeline stages |
| `acceptEdits` | Auto-approves file edits; still prompts for Bash, MCP | Stages that primarily write files |
| `dontAsk` | Never prompts — skips any action that would need approval | Background agents, read-only analysis |
| `bypassPermissions` | All actions auto-approved (dangerous) | Fully trusted automation only |
| `plan` | Agent enters plan mode; no writes until user approves | Complex stages needing user review |

### 4.2 Permission Strategy by Dispatch Mode

| Dispatch Mode | Recommended Permission Approach |
|---------------|-------------------------------|
| Foreground (interactive) | `default` — user can approve as prompted |
| Background | `dontAsk` — prompts would hang silently since user can't respond |
| Parallel (foreground) | `default` — but be aware multiple permission prompts may appear |
| Sequential chain | `default` or `acceptEdits` depending on the stage |

### 4.3 Preventing Permission Hangs

A permission hang occurs when a background agent encounters an action requiring
user approval but cannot prompt the user. The agent silently stalls.

**Prevention checklist before background dispatch:**
1. Does the agent need Bash? → Set `permissionMode: dontAsk` or pre-approve
2. Does the agent need Write/Edit? → Set `permissionMode: acceptEdits` or `dontAsk`
3. Does the agent need MCP tools? → MCP is unavailable in background; use foreground
4. Does the agent call AskUserQuestion? → Cannot work in background; use foreground

### 4.4 Project-Level Subagent Hooks

Subagent lifecycle events can trigger hooks defined in `.claude/settings.json`:

```json
{
  "hooks": {
    "SubagentStart": [{
      "matcher": { "agentName": "agent-name" },
      "hooks": [{ "type": "command", "command": "echo 'Agent starting'" }]
    }],
    "SubagentStop": [{
      "matcher": { "agentName": "agent-name" },
      "hooks": [{ "type": "command", "command": "echo 'Agent finished'" }]
    }]
  }
}
```

Use cases:
- Log agent start/stop times for pipeline metrics
- Validate prerequisites before an agent begins
- Run cleanup after an agent completes
- Notify external systems of agent activity

---

## 5. Composing Dispatch Prompts

### 5.1 Mandatory Fields

Every subagent dispatch prompt must include:

1. **Task description** — what to accomplish, in clear terms
2. **Working path** — the directory where the agent should operate
3. **Relevant file paths** — which files to read (don't make the agent search)
4. **Current state** — pipeline stage status, known issues, constraints
5. **Expected output** — what to produce (files, summaries, decisions)
6. **Constraints** — what NOT to do, tool limitations, known pitfalls

### 5.2 What NOT to Include

- Orchestrator conversation history (agents don't see it anyway)
- Raw file contents (let the agent read files itself — it has its own context)
- Unrelated project context (other stages, other projects)
- Lengthy background explanations the agent's preloaded skills already cover

### 5.3 Dispatch Prompt Template

Use this structure for consistent, effective subagent dispatch:

```
## Task: {Clear one-line description}

**Project:** {project-id}
**Working path:** `{path to project or working directory}`
**Primary files:** `{path to key file(s)}`

### Context
{2-3 sentences of essential background — current state, what's been done}

### Your Tasks
1. {Specific action with file paths}
2. {Specific action with expected output}
3. {Specific action with success criteria}

### Constraints
- {Hard limitation 1}
- {Hard limitation 2}
- {Known pitfall to avoid}

### Files to Read
- `{path}` — {what it contains and why to read it}
- `{path}` — {what it contains and why to read it}

### Expected Output
{What the agent should produce — files, summaries, decisions}
```

### 5.4 Prompt Quality Checklist

Before dispatching, verify:
- [ ] Could a fresh agent complete this task with only the prompt and its preloaded skills?
- [ ] Are all file paths absolute or resolvable from the working path?
- [ ] Is the expected output format specified (files, JSON, markdown summary)?
- [ ] Are constraints explicit (not implied by context the agent won't have)?
- [ ] Is the task scoped tightly enough to complete in one agent session?

### 5.5 Stages Dispatch Table

| Stage | Command | Subagent | Skills |
|-------|---------|----------|--------|
| 01-scoping | `/stage-01-scoping` | scoping-agent | agent-first-architecture, prompt-engineering |
| 02-agent-architecture | `/stage-02-agent-architecture` | architecture-agent | agent-first-architecture, tool-calling-design, multi-agent-orchestration, ai-security |
| 03-context-design | `/stage-03-context-design` | context-design-agent | context-interface-design, rag-engineering |
| 04-ai-integration | `/stage-04-ai-integration` | integration-agent | llm-api-integration, llm-providers, rag-engineering, vector-databases |
| 05-implementation | `/stage-05-implementation` | implementation-agent | full-stack-architecture, frontend-development, backend-development |
| 06-evaluation | `/stage-06-evaluation` | evaluation-agent | testing-qa, evaluation-tools, ai-security |
| 07-deployment | `/stage-07-deployment` | deployment-agent | devops-deployment, observability |

**Parallel stages:** None (stages are sequential)
**Convergent stages:** 06-evaluation (draws from all prior stages)
**Heaviest stage:** 05-implementation
**Maximum rework iterations:** 3

---

## 6. Monitoring Active Agents

### 6.1 What the Orchestrator Can Observe

For **foreground** agents: the orchestrator blocks until completion. The result
message contains whatever the agent produced.

For **background** agents: use `TaskOutput` with `block: false` to check
status without waiting. The output includes:
- Whether the agent is still running or completed
- Partial output if available
- The output file path for later retrieval

### 6.2 Signs of Needed Intervention

Monitor for these signals after agent completion:
- **Empty or minimal result** — agent may have hit a permission wall or tool failure
- **Result mentions "unable to" or "could not"** — agent encountered a blocker
- **Agent completed very quickly** — may have failed early without useful work
- **Agent completed very slowly** — may have hit iteration loops or context limits
- **Missing expected artifacts** — files the agent was supposed to create don't exist

### 6.3 Tracking Active Agents

When running multiple background agents, track them:

```
Active agents:
- Agent A (task-id: abc123) — analyzing requirements [dispatched 2 min ago]
- Agent B (task-id: def456) — generating output files [dispatched 1 min ago]
```

Check each with `TaskOutput(task_id, block=false)` to poll status.

---

## 7. Handling Subagent Results

### 7.1 Result Processing Protocol

When a subagent completes:

1. **Read the result** — it's returned as a single message
2. **Extract key facts** — pass/fail, file paths created, issues found, metrics
3. **Summarize for the user** — concise, structured, actionable
4. **Update state** — modify project-state.json if stage status changed
5. **Discard verbose details** — they live in the subagent's output, not the orchestrator

### 7.2 Machine-Parseable Gate Results

For gate reviews, request results in a structured format:

```
GATE RESULT: PASS | FAIL | WARN
CRITERIA MET: 5/6
FAILURES:
- [criterion name]: [reason]
WARNINGS:
- [criterion name]: [reason]
FILES CREATED:
- path/to/gate-review.md
```

This makes it easy to extract pass/fail without parsing prose.

### 7.3 Resuming Subagents

Subagents can be resumed by ID to continue previous work without starting
fresh. Use this when:

- A subagent was interrupted and needs to finish
- You want to ask follow-up questions about an agent's work
- An agent needs to do a second pass after feedback

**Pattern:** Pass the `resume` parameter with the agent ID from the previous
invocation. The agent continues with full previous context preserved.

**When to resume vs dispatch new:**

| Situation | Resume | New Dispatch |
|-----------|--------|-------------|
| Agent was interrupted mid-work | Yes | No |
| Follow-up question about agent's output | Yes | No |
| Agent needs to redo work with different parameters | No | Yes |
| Completely different task | No | Yes |
| Agent's context is stale (hours later) | No | Yes |

---

## 8. Failure Recovery

### 8.1 Failure Classification

When a subagent fails or produces unexpected results, classify the failure:

| Failure Type | Symptoms | Recovery |
|-------------|----------|----------|
| **Tool failure** | MCP timeout, CLI error, missing tool | Fix the tool issue, re-dispatch |
| **Context failure** | Agent didn't have enough info, wrong assumptions | Re-dispatch with better prompt |
| **Scope failure** | Task too large for one agent session | Split into subtasks, dispatch sequentially |
| **Permission failure** | Agent hit unapproved action, stalled | Adjust permissionMode, re-dispatch |
| **Interruption** | Agent stopped mid-work (context limit, timeout) | Resume the agent by ID |

### 8.2 Recovery Decision Tree

```
Agent failed or produced bad results
  ↓
Was it a tool issue? (MCP down, CLI missing, wrong params)
  → YES: Fix the tool, re-dispatch with same prompt
  → NO: Continue...

Was it a context issue? (missing info, wrong assumptions)
  → YES: Re-dispatch with enriched prompt (add missing context)
  → NO: Continue...

Was it a scope issue? (too much work, hit context limits)
  → YES: Split task, dispatch subtasks sequentially
  → NO: Continue...

Was the agent interrupted? (timeout, user cancel)
  → YES: Resume the agent by ID
  → NO: Continue...

Was it a permission issue? (hung on approval)
  → YES: Set appropriate permissionMode, re-dispatch
  → NO: Ask the user for guidance
```

### 8.3 Retry Limits

- **Maximum 3 retries** for the same task with the same approach
- After 3 failures, escalate to the user with:
  - What was attempted (all 3 approaches)
  - What failed each time
  - Suggested alternative approaches
- Never loop indefinitely on a failing dispatch

### 8.4 Post-Failure Learning

After recovering from a failure:
1. Log the failure and resolution in `issues-log.md` (or the project's issues array)
2. If the failure reveals a skill gap, note it for `/skill-update`
3. If the failure reveals a tool issue, note it for `/env-check`
4. Consider whether the dispatch prompt template needs adjustment

---

## 9. Agent Teams

Agent teams are a coordination mechanism where multiple independent Claude Code
sessions collaborate via a shared task list and messaging system.

### 9.1 Architecture

A team consists of:
- **Lead agent** — the orchestrator session that creates and manages the team
- **Teammate agents** — independent Claude Code sessions spawned by the lead
- **Shared task list** — visible to all team members via the `TaskList` tool
- **Mailbox** — teammates can send messages to the lead and each other

### 9.2 When to Use Teams vs Subagents

| Scenario | Use Subagents | Use Teams |
|----------|--------------|-----------|
| Focused task, result needed quickly | Yes | No |
| Parallel independent research | Yes (parallel dispatch) | Yes |
| Workers need to discuss/challenge each other | No | Yes |
| Workers need to coordinate on shared files | No | Yes (with care) |
| Cost-sensitive | Yes (lower token usage) | No |
| Sequential pipeline stages | Yes | No |
| Competing hypotheses / adversarial review | No | Yes |
| Cross-cutting changes (multiple areas + tests) | Maybe | Yes |

### 9.3 Enabling Teams

Agent teams require the experimental flag:
```json
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
```

Set this in `.claude/settings.json` or `.claude/settings.local.json`.

### 9.4 Communication Patterns

- **Lead → Teammate:** Create tasks in the shared task list
- **Teammate → Lead:** Complete tasks, add results as task comments
- **Teammate → Teammate:** Via shared task list (not direct messaging)
- **Plan approval flow:** Lead creates a plan, teammates review and provide feedback via tasks

### 9.5 Quality Gates for Teams

Use subagent lifecycle hooks to monitor team quality:
- `SubagentStop` hook can check if the teammate completed its assigned tasks
- Lead agent should verify all tasks are complete before proceeding
- Set `maxTurns` on teammates to prevent runaway token usage

### 9.6 Known Limitations

- No session resumption with in-process teammates
- Task status can lag — teammates may not mark tasks complete promptly
- One team per session
- No nested teams (a teammate cannot create its own team)
- Split panes require tmux or iTerm2 on Unix; limited on Windows

---

## 10. Model Selection

| Task Type | Recommended Model | Reasoning |
|-----------|------------------|-----------|
| 01-scoping (Domain and Intent Scoping) | `inherit` (Opus) | Requires deep domain understanding and creative structuring |
| 02-agent-architecture (Agent Architecture Design) | `inherit` (Opus) | Critical architecture decisions need strongest reasoning |
| 03-context-design (Context Interface Design) | `sonnet` | Structured design work with clear patterns |
| 04-ai-integration (AI Platform Integration) | `sonnet` | Configuration and integration, well-defined outputs |
| 05-implementation (Application Implementation) | `inherit` (Opus) | Complex code generation across full stack |
| 06-evaluation (Agent Evaluation and Testing) | `sonnet` | Systematic testing with established frameworks |
| 07-deployment (Deployment and Packaging) | `sonnet` | Standard DevOps patterns, structured output |
| Quick file search / exploration | `haiku` | Fast, cheap, sufficient for read-only |
| Code review / analysis | `sonnet` | Good balance of speed and quality |
| Gate review checks | orchestrator-direct | Too simple for a subagent |
| Strategy / architecture decisions | `inherit` (Opus) | Requires deep reasoning |
| Template generation / boilerplate | `sonnet` | Structured, predictable output |
| Background monitoring / polling | `haiku` | Minimal reasoning needed |

Set model in the dispatch: `model: "haiku"` for Task tool calls, or
in the agent's frontmatter `model: sonnet` for persistent agents.

---

## 11. Anti-Patterns

### DO NOT:

1. **Read large domain artifacts in the orchestrator** — delegate to a subagent
2. **Run verbose tools in the orchestrator** — delegate to a subagent
3. **Forward raw subagent output to the user** — summarize it
4. **Dispatch subagents for trivial tasks** — reading project-state.json,
   checking git status, updating a JSON field are orchestrator-direct
5. **Dispatch dependent agents in parallel** — if B needs A's result,
   run them sequentially
6. **Give subagents vague prompts** — "fix the project" is bad;
   specific tasks with file paths, constraints, and expected output are good
7. **Duplicate subagent work** — if you dispatched a research agent,
   don't also do the same research yourself
8. **Dispatch agents without checking prerequisites** — always verify
   project state before dispatching a pipeline stage agent
9. **Let subagent results bloat orchestrator context** — if a result is
   large, extract key facts and discard the rest
10. **Nest subagent calls** — subagents cannot spawn other subagents;
    if multi-level delegation is needed, chain from the orchestrator
11. **Dispatch background agents that need user interaction** — they
    cannot prompt for permissions, ask questions, or enter plan mode
12. **Ignore failed agents** — always classify the failure (§8.1) and
    either recover or escalate to the user
13. **Retry the same failing approach** — after 2 failures with identical
    parameters, change the approach before trying again
14. **Skip the dispatch prompt template** — ad-hoc prompts miss critical
    context; use the template from §5.3 consistently

### AI-Centric Apps Orchestration Notes

- The **evaluation stage (06)** is convergent — it draws from ALL prior stages' artifacts. When dispatching the evaluation agent, include references to key artifacts from every completed stage, not just the implementation.
- **Prompt library versioning** is critical. When re-dispatching the integration agent after architecture changes, always note which prompt versions are current vs stale.
- **RAG pipeline testing** requires the ChromaDB MCP server. If dispatching evaluation or integration agents that need RAG, verify ChromaDB is available (foreground only — MCP is unavailable in background).
- **Security audit** during evaluation should be dispatched as a convergent review with at least one agent focused purely on prompt injection and one on data leakage.
