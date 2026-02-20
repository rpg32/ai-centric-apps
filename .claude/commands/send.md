# Send

Compose and send a message to a registered peer system from the AI-Centric Apps system.

## Usage
```
/send {peer-system-id} [--blocking] [--thread {thread-id}]
```

## Workflow

1. Resolve peer from `comms/peers.json`
2. Compose message (subject, body, type, urgency)
3. Build message JSON
4. Save to outbox and deliver to peer's inbox
5. If --blocking: invoke `claude -p` in peer directory for immediate response
6. If non-blocking: report delivery and add waiting_on if needed
7. Git commit
