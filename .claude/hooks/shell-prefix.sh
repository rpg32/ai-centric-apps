#!/bin/bash

# AI-Centric Apps Shell Prefix
#
# Runs before every Bash command via CLAUDE_CODE_SHELL_PREFIX.
# Sources the per-session env file to load SYSTEM_* variables.

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HOOKS_DIR/session-env.sh" ] && source "$HOOKS_DIR/session-env.sh"
[ -n "$CLAUDE_SESSION_ID" ] && [ -f "$HOOKS_DIR/sessions/$CLAUDE_SESSION_ID.sh" ] && source "$HOOKS_DIR/sessions/$CLAUDE_SESSION_ID.sh"
eval "$@"
