# Inbox

Check and process incoming messages from peer systems for the AI-Centric Apps system.

## Usage
```
/inbox [--auto]
```

- No arguments: Interactive mode -- display pending messages and let user decide
- `--auto`: Auto-processing mode -- used internally before pipeline commands

## Workflow

1. Scan `comms/inbox/` for `.json` files
2. Sort by urgency (blocking first) then date
3. In interactive mode, ask which to process
4. Process each message based on type (response, question, spec-sheet, notification, follow-up)
5. In auto mode, only process blocking messages
6. Move processed messages to thread directories
7. Git commit
