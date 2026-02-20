# Register Peer

Register another expert system as a communication peer for the AI-Centric Apps system. This creates a bidirectional link -- both systems can send and receive messages from each other.

## Usage
```
/register-peer {peer-system-path}
```

## Workflow

1. Validate peer path (check for `.claude/CLAUDE.md` and `comms/` directory)
2. Check for existing registration
3. Register peer in own `comms/peers.json`
4. Register self in peer's `comms/peers.json`
5. Confirm both registrations
6. Git commit in SYSTEM repo
