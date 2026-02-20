# Reply

Reply to a message in an existing communication thread with a peer system.

## Usage
```
/reply {thread-id} [--blocking]
```

## Workflow

1. Find the thread in `comms/threads/{thread-id}/`
2. Identify the last message and determine reply recipient
3. Compose reply (body, type, attachments)
4. Build message JSON inheriting thread context
5. Save to outbox and deliver to peer's inbox
6. If --blocking: invoke `claude -p` for immediate response
7. Update project state if waiting_on is affected
8. Git commit
