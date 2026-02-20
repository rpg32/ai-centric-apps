---
name: context-interface-design
description: Design context windows, context tools, and interaction patterns for agent-first applications following the tool inversion principle, with platform-specific adaptation for web, desktop, mobile, and CLI.
user-invocable: false
---

# Context Interface Design

## Purpose

Enable Claude to design the context facilitator layer of agent-first applications: context windows that display information, context tools that let users provide structured data to agents, and interaction patterns that implement bidirectional context flow. This is NOT traditional UI design -- the UI exists to mediate context between users and agents.

## Key Rules

1. **Every Agent Gets At Least One Context Window**: A context window is a visual panel where the user sees information relevant to an agent's domain. If an agent has no context window, the user cannot provide structured context to it. Minimum: one context window per agent.

2. **Every Context Window Gets At Least One Context Tool**: A context tool is a UI interaction (selection, annotation, constraint) that produces structured data for the agent. A context window without context tools is just a display -- the user cannot provide structured context through it.

3. **Context Data Format Must Be JSON**: Every context tool must produce a JSON object with: `context_type` (string), `source` (string identifying the context window), `data` (object with the structured payload). This format is injected into the agent's prompt.

4. **Response Rendering Is Mandatory**: Every agent response must have a defined rendering target -- which context window displays the result and in what format (inline annotation, side panel, replacement, new window). Responses that are not rendered leave the user without feedback.

5. **Context Granularity Follows the 3-Second Rule**: If a user takes >3 seconds to provide context via a context tool, the tool is too complex. Context tools should be single-action (click, select, drag) or brief (type 1-2 words, set a slider). Complex context should be broken into multiple simple tools.

6. **Platform Adaptation Is Required**: Context windows and tools must adapt to the deployment platform. A 3-panel layout works on desktop but not mobile. A text selection tool works on web but not CLI. Design for the target platform first; do not design for web and then adapt.

7. **Progressive Disclosure for Context**: Show essential context in the primary view. Additional context available on expand/hover/click. Never show all available context at once -- it overwhelms both the user and the token budget.

## Decision Framework

### Choosing Context Window Types

```
What information does the agent need the user to interact with?
|
+-- Text documents (code, prose, markdown)
|   --> Document viewer context window
|       Context tools: line/range selection, annotation, search
|       Rendering: inline highlights, margin annotations, diff view
|
+-- Structured data (tables, lists, records)
|   --> Data table context window
|       Context tools: row/column selection, filter, sort
|       Rendering: highlighted rows, inline edits, cell annotations
|
+-- Visual content (images, diagrams, maps)
|   --> Canvas/viewer context window
|       Context tools: region selection, pin/marker placement, zoom
|       Rendering: overlay annotations, bounding boxes, labels
|
+-- Conversation history
|   --> Chat context window
|       Context tools: message reference (reply-to), reaction, quote
|       Rendering: streamed text, tool call indicators, attachments
|
+-- File system / project structure
|   --> Tree view context window
|       Context tools: file/folder selection, multi-select, drag
|       Rendering: status indicators, badges, inline previews
|
+-- Timeline / temporal data
    --> Timeline context window
        Context tools: date range selection, event marking, zoom
        Rendering: event cards, markers, period highlights
```

### Platform-Specific Layout Decisions

```
What is the deployment target?
|
+-- Web application (desktop browser)
|   --> Multi-panel layout (2-3 panels)
|       Main panel: primary context window (60% width)
|       Side panel: chat + agent output (30% width)
|       Top bar: navigation + global context tools (10% height)
|       Framework: React/Next.js, Svelte/SvelteKit
|
+-- Web application (mobile browser)
|   --> Single-panel with tabs/sheets
|       Full-screen: one context window at a time
|       Bottom sheet: chat input + agent output
|       Top: tab bar to switch context windows
|       Framework: React (responsive) or React Native Web
|
+-- Desktop application (Electron/Tauri)
|   --> Multi-panel with resizable splits
|       Can have 3-4 panels simultaneously
|       OS-level context tools (clipboard, file drag-drop, notifications)
|       Framework: Electron + React, or Tauri + web frontend
|
+-- CLI tool
|   --> Sequential text interaction
|       Context: file paths, stdin piping, command flags
|       Context tools: argument flags, interactive prompts (inquirer)
|       Output: formatted text, tables, JSON, file output
|       Framework: Python (click/typer) or Node (commander)
|
+-- Mobile native app
    --> Single-panel with navigation stack
        Full-screen: one context window with gesture-based context tools
        Modal/sheet: agent interaction panel
        Framework: React Native, Flutter
```

## Procedures

### Procedure 1: Design Context Windows for an Agent

1. **List the agent's action tools**: Each tool tells you what context the agent needs.
   ```
   Agent: document-editor
   Tools: modify_section(doc_id, section, content), insert_section(doc_id, after, content)
   Needed context: document content, section boundaries, cursor position
   ```

2. **Design a context window** that displays the relevant information:
   ```
   Context Window: "Document Editor"
   Displays: full document with section headers, paragraph text, code blocks
   Layout: scrollable document view with left gutter for section markers
   ```

3. **Add context tools** that produce structured data matching tool parameters:
   ```
   Context Tools:
   - Section selector: click section header -> {context_type: "section_select", source: "doc-editor", data: {doc_id: "abc", section: "introduction"}}
   - Text highlight: drag over text -> {context_type: "text_select", source: "doc-editor", data: {doc_id: "abc", start: 100, end: 250, text: "selected text..."}}
   - Insert marker: click between sections -> {context_type: "insert_point", source: "doc-editor", data: {doc_id: "abc", after_section: "methodology"}}
   ```

4. **Define rendering targets** for agent responses:
   ```
   Rendering:
   - modify_section result -> highlight changed section with diff (green = added, red = removed)
   - insert_section result -> scroll to new section with pulse animation
   - Error responses -> toast notification with error message
   ```

5. **Validate bidirectional flow**: For each user goal, trace the complete path:
   ```
   Goal: "Rewrite the introduction"
   1. User clicks "Introduction" section header (section_select context tool)
   2. Context data sent to agent: {section: "introduction", content: "current text..."}
   3. Agent calls modify_section(doc_id, "introduction", "new text...")
   4. Result rendered: section updated with diff highlight
   5. User sees the change and can undo/accept
   ```

### Procedure 2: Create Context Tool Inventory

1. **For each context window**, list all context tools with this template:

   | Tool Name | User Action | Structured Output | Agent Consumer | Frequency |
   |-----------|------------|-------------------|---------------|-----------|
   | Section select | Click section header | `{context_type, doc_id, section}` | document-editor | Every interaction |
   | Text highlight | Drag over text | `{context_type, doc_id, start, end, text}` | document-editor | Most interactions |
   | Insert point | Click between sections | `{context_type, doc_id, after_section}` | document-editor | Occasional |

2. **Validate completeness**: Every agent action tool must have at least one context tool that provides its required input data. Cross-reference:

   | Action Tool | Required Context | Context Tool(s) That Provide It |
   |------------|-----------------|-------------------------------|
   | modify_section | doc_id, section | Section select |
   | insert_section | doc_id, after | Insert point |

3. **Check for missing context paths**: If any action tool has no matching context tool, either:
   - The action tool is autonomous (does not need user context) -- document why
   - A context tool is missing -- design and add it

### Procedure 3: Design Interaction Patterns

1. **Map each primary user goal** to a complete interaction pattern:
   ```
   Pattern: "Ask a question about a document"
   Trigger: User types a question in the chat input
   Context flow:
     1. Chat input captures user question (implicit context tool)
     2. Current document context is included (active document, visible section)
     3. Agent receives: question + document context + conversation history
     4. Agent calls search_documents or analyze_section
     5. Response rendered in chat panel with source citations
     6. Cited sections highlighted in document viewer
   ```

2. **Document timing expectations**:
   - Context tool interaction: <3 seconds (user action)
   - Context data processing: <100ms (serialization)
   - Agent response (simple): <5 seconds
   - Agent response (complex/multi-tool): <15 seconds
   - Rendering: <200ms after response received

3. **Design streaming behavior**: For agent responses >2 seconds:
   - Show typing indicator immediately
   - Stream text responses token-by-token
   - Show tool call indicators when agent invokes tools
   - Render final result when complete

## Reference Tables

### Context Tool Types

| Type | User Action | Output Schema | Platform Support |
|------|------------|---------------|-----------------|
| Selection | Click, highlight, tap | `{type: "selection", target_id, range}` | Web, Desktop, Mobile |
| Annotation | Add note, comment, tag | `{type: "annotation", target_id, text, position}` | Web, Desktop, Mobile |
| Constraint | Slider, dropdown, toggle | `{type: "constraint", param, value}` | Web, Desktop, Mobile, CLI |
| Focus | Navigate, zoom, scroll | `{type: "focus", viewport, center}` | Web, Desktop, Mobile |
| Upload | Drag-drop, file picker | `{type: "upload", filename, content, mime_type}` | Web, Desktop, Mobile |
| Reference | @mention, link, quote | `{type: "reference", target_type, target_id}` | Web, Desktop, Mobile, CLI |
| Gesture | Pinch, swipe, long-press | `{type: "gesture", gesture_type, coordinates}` | Mobile only |
| Keyboard | Shortcut, command palette | `{type: "command", action, args}` | Web, Desktop |

### Response Rendering Patterns

| Pattern | Description | Use When |
|---------|-------------|----------|
| Inline annotation | Response appears within the source content | Edits, corrections, highlights |
| Side panel | Response in adjacent panel | Analysis, explanation, detailed feedback |
| Replacement | Response replaces selected content | Content generation, rewriting |
| Overlay | Response as floating card/tooltip | Quick info, previews, summaries |
| New window | Response opens a new context window | Complex results, generated artifacts |
| Stream | Response appears token-by-token | Chat responses, long-form generation |
| Toast | Brief notification | Confirmations, errors, status updates |

### Platform UI Component Mapping

| Concept | Web (React) | Desktop (Electron) | Mobile (React Native) | CLI (Python) |
|---------|-------------|-------------------|---------------------|-------------|
| Context Window | `<Panel>` component | `BrowserWindow` pane | `Screen` in navigation stack | stdout section |
| Selection Tool | `onMouseUp` + `Selection` API | Same + OS selection | `onLongPress` + text selection | Argument flags |
| Annotation Tool | `contentEditable` + overlay | Same + native tooltip | `TextInput` modal | Interactive prompt |
| Constraint Tool | `<input>`, `<select>`, `<Slider>` | Same + native widgets | Native `Picker`, `Slider` | CLI flags/options |
| Streaming | `EventSource` / WebSocket | Same | Same | Generator + `print()` |

## Failure Modes

| Failure | Symptoms | Root Cause | Fix |
|---------|----------|------------|-----|
| Context Starvation | Agent gives generic responses despite user interacting with context windows | Context tools do not produce useful structured data, or data not injected into prompt | Verify each context tool outputs JSON with meaningful data. Check that context data reaches the agent prompt. Test with real user interactions. |
| Context Overload | Agent ignores user context, or responses become incoherent | Too many context tools firing simultaneously, or context data exceeds token budget | Implement context prioritization. Only send context from the active context window. Cap total context at 4,000 tokens. |
| Wrong Rendering Target | Agent response appears in the wrong place or format | Response rendering not mapped to the correct context window | Update the rendering configuration to map each agent tool's output type to the correct window and format. |
| Platform Mismatch | UI breaks on the target platform (mobile overflow, CLI missing interactivity) | Designed for web, then adapted without platform-specific adjustments | Start design from the target platform's constraints. Test early on actual devices/terminals. |
| Slow Context Tool | User interaction feels laggy, >3 seconds to provide context | Context tool does complex processing before sending data | Move processing to async. Send raw context data immediately, process in background. |
| Missing Undo | User cannot reverse an action the agent took based on their context input | No undo mechanism designed for destructive agent actions | Add undo/revert for all modify and delete agent actions. Store previous state before agent action. |

## Examples

### Example 1: Context Interface for a Code Review Application

**Platform**: Web application (desktop browser)

**Layout**: 3-panel
- Left (20%): file tree context window
- Center (50%): code viewer context window
- Right (30%): review panel (chat + findings)

**Context Windows and Tools**:

| Window | Context Tools | Agent Consumer |
|--------|--------------|---------------|
| File Tree | File select (click), Multi-select (ctrl+click) | review-agent |
| Code Viewer | Line range select (click+drag), Annotation (right-click -> add note) | review-agent |
| Review Panel | Severity filter (dropdown), Category filter (checkboxes) | review-agent |

**Interaction Pattern -- "Review this function"**:
1. User selects `auth.py` in file tree -> `{context_type: "file_select", file: "auth.py"}`
2. Code viewer displays `auth.py` content
3. User selects lines 45-80 (the `login()` function) -> `{context_type: "code_select", file: "auth.py", start_line: 45, end_line: 80}`
4. User types "Review this function for security issues" in chat
5. Agent receives: code selection + user message + file context
6. Agent calls `analyze_code_quality(file="auth.py", metrics=["security"])`
7. Response rendered: findings appear in review panel, affected lines highlighted in code viewer

### Example 2: Context Interface for a CLI Tool

**Platform**: Terminal (Python CLI)

**Context Tools** (mapped to CLI concepts):

| CLI Concept | Context Tool Type | Example |
|-------------|------------------|---------|
| Positional argument | Focus (file path) | `tool review auth.py` |
| Flag | Constraint | `--severity high --format json` |
| Stdin pipe | Upload | `cat code.py \| tool review` |
| Interactive prompt | Annotation | "Enter your review focus: security" |

**Interaction Pattern**:
```bash
# User provides context via CLI arguments and flags
ai-review auth.py --focus security --severity high

# Agent receives structured context:
# {file: "auth.py", focus: "security", severity_filter: "high"}

# Agent response rendered to stdout:
# === Code Review: auth.py ===
# Focus: Security | Severity: high and above
#
# [HIGH] Line 52: SQL query uses string formatting instead of parameterized queries
#   Suggestion: Use parameterized queries to prevent SQL injection
#   Fix: cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
```
