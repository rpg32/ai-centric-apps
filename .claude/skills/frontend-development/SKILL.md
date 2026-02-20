---
name: frontend-development
description: Building context interfaces for agent-first applications using React/Next.js, Svelte, Electron, Tauri, or CLI frameworks, with SSE streaming integration and responsive context window layouts.
user-invocable: false
---

# Frontend Development for Agent-First Applications

## Purpose

Enable Claude to implement context interfaces (context windows and context tools) using the framework specified in tech-stack-decision.json. Covers component architecture, streaming response rendering, context tool implementation, and platform-specific adaptation.

## Key Rules

1. **Context Windows Are Components**: Each context window maps to a React component (or Svelte component, etc.). The component receives: (a) data to display, (b) callback functions for context tool events, (c) agent response rendering props. Use a consistent `ContextWindow` base component.

2. **Context Tools Emit Structured Events**: Every context tool interaction must dispatch a typed event containing JSON context data. Use a central `contextBus` or React context to collect and forward context events to the agent API.

3. **Streaming Is the Default**: All agent-facing API calls must use SSE or WebSocket. The frontend must render tokens as they arrive. Use a `useAgentStream` hook (React) or similar abstraction. Never use `fetch().then(json)` for agent calls.

4. **Responsive Layout Breakpoints**: Desktop (>1024px): multi-panel layout with 2-3 context windows visible. Tablet (768-1024px): 2 panels or tabbed. Mobile (<768px): single panel with bottom sheet for chat. Always test at each breakpoint.

5. **Loading States for Agent Interactions**: Show typing indicator within 200ms of sending a request. Show streamed content as it arrives. Show tool-call indicators when agent invokes tools. Show final result after stream completes. Never leave the user with a blank screen.

6. **Keyboard Shortcuts for Power Users**: Essential shortcuts: Cmd/Ctrl+Enter to send message, Escape to cancel, Cmd/Ctrl+K for command palette. Context tools should have keyboard alternatives to mouse interactions.

## Decision Framework

### Choosing a Frontend Framework

```
What does tech-stack-decision.json specify?
|
+-- Web application (React)
|   --> React + Vite (SPA) or Next.js (SSR + API routes)
|       State management: React Context + useReducer (simple) or Zustand (complex)
|       Streaming: EventSource API or fetch with ReadableStream
|       UI library: shadcn/ui (recommended) or Tailwind CSS (minimal)
|
+-- Web application (Svelte)
|   --> SvelteKit
|       State management: Svelte stores
|       Streaming: fetch with ReadableStream
|       UI library: Skeleton UI or Tailwind CSS
|
+-- Desktop (Electron)
|   --> Electron + React
|       Additional: IPC for OS-level tools (clipboard, file system)
|       Streaming: Same as web (Chromium-based)
|
+-- Desktop (Tauri)
|   --> Tauri + React or Svelte
|       Additional: Tauri commands for OS-level tools
|       Streaming: Same as web
|
+-- Mobile
|   --> React Native or Flutter
|       Streaming: fetch with ReadableStream (React Native)
|       Layout: single panel + bottom sheet
|
+-- CLI
    --> Python (click/typer) or Node.js (commander/inquirer)
        Output: rich terminal output (Python: rich library)
        Streaming: print tokens as they arrive
```

## Procedures

### Procedure 1: Implement a Streaming Chat Component (React)

1. **Create the useAgentStream hook**:
   ```typescript
   // hooks/useAgentStream.ts
   import { useState, useCallback } from 'react';

   interface StreamState {
     content: string;
     isStreaming: boolean;
     toolCalls: ToolCall[];
     error: string | null;
   }

   export function useAgentStream() {
     const [state, setState] = useState<StreamState>({
       content: '', isStreaming: false, toolCalls: [], error: null
     });

     const sendMessage = useCallback(async (
       messages: Message[],
       context: ContextData | null
     ) => {
       setState(s => ({ ...s, content: '', isStreaming: true, error: null }));

       try {
         const response = await fetch('/api/chat', {
           method: 'POST',
           headers: { 'Content-Type': 'application/json' },
           body: JSON.stringify({ messages, context })
         });

         const reader = response.body!.getReader();
         const decoder = new TextDecoder();

         while (true) {
           const { done, value } = await reader.read();
           if (done) break;

           const lines = decoder.decode(value).split('\n')
             .filter(l => l.startsWith('data: '));

           for (const line of lines) {
             const data = line.slice(6);
             if (data === '[DONE]') break;
             const parsed = JSON.parse(data);
             if (parsed.content) {
               setState(s => ({ ...s, content: s.content + parsed.content }));
             }
             if (parsed.tool_call) {
               setState(s => ({
                 ...s,
                 toolCalls: [...s.toolCalls, parsed.tool_call]
               }));
             }
           }
         }
       } catch (err) {
         setState(s => ({ ...s, error: (err as Error).message }));
       } finally {
         setState(s => ({ ...s, isStreaming: false }));
       }
     }, []);

     return { ...state, sendMessage };
   }
   ```

2. **Create the ChatPanel component**:
   ```tsx
   // components/ChatPanel.tsx
   export function ChatPanel({ context }: { context: ContextData | null }) {
     const { content, isStreaming, sendMessage, error } = useAgentStream();
     const [input, setInput] = useState('');
     const [messages, setMessages] = useState<Message[]>([]);

     const handleSend = async () => {
       if (!input.trim()) return;
       const userMsg = { role: 'user', content: input };
       setMessages(prev => [...prev, userMsg]);
       setInput('');
       await sendMessage([...messages, userMsg], context);
     };

     return (
       <div className="flex flex-col h-full">
         <div className="flex-1 overflow-y-auto p-4">
           {messages.map((msg, i) => (
             <MessageBubble key={i} message={msg} />
           ))}
           {isStreaming && <StreamingIndicator content={content} />}
           {error && <ErrorBanner message={error} />}
         </div>
         <div className="p-4 border-t">
           <ChatInput
             value={input}
             onChange={setInput}
             onSubmit={handleSend}
             disabled={isStreaming}
           />
         </div>
       </div>
     );
   }
   ```

### Procedure 2: Implement a Context Tool

1. **Create a text selection context tool** (React):
   ```tsx
   // components/context-tools/TextSelection.tsx
   import { useContext } from 'react';
   import { ContextBusContext } from '@/contexts/ContextBus';

   export function TextSelectionTool({ documentId }: { documentId: string }) {
     const { emitContext } = useContext(ContextBusContext);

     const handleMouseUp = () => {
       const selection = window.getSelection();
       if (!selection || selection.isCollapsed) return;

       const range = selection.getRangeAt(0);
       const text = selection.toString();

       emitContext({
         context_type: 'text_selection',
         source: `document-viewer-${documentId}`,
         data: {
           document_id: documentId,
           selected_text: text,
           start_offset: range.startOffset,
           end_offset: range.endOffset
         }
       });
     };

     return (
       <div onMouseUp={handleMouseUp} className="select-text cursor-text">
         {/* Document content rendered here */}
       </div>
     );
   }
   ```

2. **Create the context bus** (central event aggregator):
   ```tsx
   // contexts/ContextBus.tsx
   import { createContext, useState, useCallback } from 'react';

   interface ContextEvent {
     context_type: string;
     source: string;
     data: Record<string, unknown>;
   }

   export const ContextBusContext = createContext<{
     currentContext: ContextEvent | null;
     emitContext: (event: ContextEvent) => void;
     clearContext: () => void;
   }>({ currentContext: null, emitContext: () => {}, clearContext: () => {} });

   export function ContextBusProvider({ children }: { children: React.ReactNode }) {
     const [currentContext, setCurrentContext] = useState<ContextEvent | null>(null);

     const emitContext = useCallback((event: ContextEvent) => {
       setCurrentContext(event);
     }, []);

     const clearContext = useCallback(() => setCurrentContext(null), []);

     return (
       <ContextBusContext.Provider value={{ currentContext, emitContext, clearContext }}>
         {children}
       </ContextBusContext.Provider>
     );
   }
   ```

## Reference Tables

### Frontend Architecture Layers

| Layer | Responsibility | React Implementation |
|-------|---------------|---------------------|
| Context Windows | Display data, host context tools | Page-level components |
| Context Tools | Capture user interactions as structured data | Event handler components |
| Context Bus | Aggregate and forward context to agent API | React Context + state |
| Agent API Client | SSE streaming, request/response | Custom hooks (useAgentStream) |
| State Management | UI state, conversation history, context state | React Context or Zustand |
| Rendering | Display agent responses in appropriate format | Conditional renderers |

### NPM Package Essentials

| Package | Purpose | Install Command |
|---------|---------|----------------|
| react, react-dom | UI framework | `npx create-next-app@latest` |
| tailwindcss | Utility-first CSS | `npm install -D tailwindcss` |
| shadcn/ui | UI component library | `npx shadcn-ui@latest init` |
| zustand | State management | `npm install zustand` |
| lucide-react | Icons | `npm install lucide-react` |
| react-markdown | Render markdown agent responses | `npm install react-markdown` |
| highlight.js | Syntax highlighting for code | `npm install highlight.js` |

## Failure Modes

| Failure | Symptoms | Root Cause | Fix |
|---------|----------|------------|-----|
| Streaming not rendering | User sees blank screen, then full response appears at once | Using `await fetch().json()` instead of streaming reader | Switch to ReadableStream consumption with incremental state updates. |
| Context tool events lost | Agent responds without user-provided context, gives generic answer | Context events dispatched but not forwarded to API call | Verify context bus connects to the API layer. Log context events. Test with console.log in emitContext. |
| Layout breaks on mobile | Panels overlap, text unreadable, buttons unreachable | Fixed-width layout without responsive breakpoints | Use Tailwind responsive classes (`md:`, `lg:`). Test at 375px, 768px, 1024px widths. |
| No loading indicator | User thinks app is frozen during 5-10s agent response | Missing streaming indicator or typing animation | Show typing indicator within 200ms of request. Stream tokens visually. Show tool-call badges. |
| Memory leak on streaming | Browser tab memory grows over time, page becomes slow | SSE connection not properly closed, or state accumulates | Close ReadableStream reader on component unmount. Limit conversation history in state. |

## Examples

### Example 1: Multi-Panel Layout for a Code Review App

```tsx
// pages/review.tsx
export default function ReviewPage() {
  return (
    <ContextBusProvider>
      <div className="flex h-screen">
        {/* Left: File Tree (20%) */}
        <div className="w-1/5 border-r overflow-y-auto">
          <FileTreeWindow onFileSelect={handleFileSelect} />
        </div>

        {/* Center: Code Viewer (50%) */}
        <div className="w-1/2 overflow-y-auto">
          <CodeViewerWindow
            file={selectedFile}
            highlights={agentHighlights}
          />
        </div>

        {/* Right: Chat + Review Panel (30%) */}
        <div className="w-3/10 border-l flex flex-col">
          <ReviewFindings findings={findings} className="flex-1" />
          <ChatPanel context={currentContext} className="h-1/3" />
        </div>
      </div>
    </ContextBusProvider>
  );
}
```
