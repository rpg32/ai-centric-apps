# Threads

View and manage communication threads with peer systems. Read-only -- does not modify any files.

## Usage
```
/threads [thread-id] [--active] [--peer {system-id}] [--waiting]
```

- No arguments: Show all threads
- `thread-id`: Show details of a specific thread
- `--active`: Only show threads with pending or unresolved messages
- `--peer {system-id}`: Filter threads by peer
- `--waiting`: Show threads that a project is waiting on

## Workflow

1. Scan `comms/threads/` directories
2. Build thread index (peer, subject, message count, status, last activity)
3. Apply filters
4. Display summary table or thread detail
5. Show project dependencies
