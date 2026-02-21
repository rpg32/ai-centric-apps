#!/bin/bash

# AI-Centric Apps Hook Handler
#
# Single entry point for SessionStart, PreToolUse:Bash, and SessionEnd hooks.
# Manages per-session environment files so multiple Claude Code instances
# in the same directory don't cross-contaminate env vars.
#
# Architecture:
#   SessionStart  → detects workspace state, writes sessions/<session_id>.sh
#   PreToolUse    → writes session-env.sh with current CLAUDE_SESSION_ID
#   SessionEnd    → deletes sessions/<session_id>.sh
#
# The shell prefix (shell-prefix.sh) sources session-env.sh to get the
# session ID, then sources the per-session env file.

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse session_id and event from stdin JSON
STDIN_DATA=$(cat)
SESSION_ID=$(echo "$STDIN_DATA" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)
EVENT=$(echo "$STDIN_DATA" | grep -o '"hook_event_name":"[^"]*"' | cut -d'"' -f4)

SESSION_DIR="$HOOKS_DIR/sessions"
ENV_FILE="$HOOKS_DIR/session-env.sh"

case "$EVENT" in
  SessionStart)
    mkdir -p "$SESSION_DIR"

    # Determine SYSTEM_ROOT from the hook's location (two levels up from .claude/hooks/)
    # Use cygpath -m on Git Bash to match git's path format (C:/... not /c/...)
    SYSTEM_ROOT="$(cd "$HOOKS_DIR/../.." && (cygpath -m "$(pwd)" 2>/dev/null || pwd))"

    # Check for active workspace
    SYSTEM_ACTIVE_DIR="$SYSTEM_ROOT"
    SYSTEM_WORKSPACE_NAME=""
    SYSTEM_WORKSPACE_BRANCH=""

    # Phase 1: Check for .system-workspace-active.json (workspace created mid-session)
    WORKSPACE_FILE="$SYSTEM_ROOT/.system-workspace-active.json"
    if [ -f "$WORKSPACE_FILE" ]; then
      SYSTEM_WORKSPACE_NAME=$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$WORKSPACE_FILE")
      SYSTEM_WORKSPACE_BRANCH=$(sed -n 's/.*"branch"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$WORKSPACE_FILE")
      SYSTEM_ACTIVE_DIR=$(sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$WORKSPACE_FILE")
    fi

    # Phase 2: Git worktree fallback (Claude Code opened directly in a worktree)
    # If Phase 1 didn't find a workspace, check if we're inside a worktree
    if [ -z "$SYSTEM_WORKSPACE_NAME" ]; then
      WT_LIST=$(git -C "$SYSTEM_ROOT" worktree list --porcelain 2>/dev/null)
      if [ -n "$WT_LIST" ]; then
        # First entry is always the main repo
        MAIN_PATH=$(echo "$WT_LIST" | sed -n '1s/^worktree //p')

        # If our resolved root differs from the main path, we're in a worktree
        if [ -n "$MAIN_PATH" ] && [ "$SYSTEM_ROOT" != "$MAIN_PATH" ]; then
          # Find our entry and extract the branch
          WT_BRANCH=$(echo "$WT_LIST" | awk -v wt="worktree $SYSTEM_ROOT" '
            $0 == wt { found=1; next }
            found && /^branch / { sub(/^branch refs\/heads\//, ""); print; exit }
            found && /^worktree / { exit }
          ')

          if [ -n "$WT_BRANCH" ]; then
            # Extract workspace name from ws/{name} pattern
            WT_NAME=$(echo "$WT_BRANCH" | sed -n 's|^ws/||p')
            if [ -n "$WT_NAME" ]; then
              SYSTEM_WORKSPACE_NAME="$WT_NAME"
              SYSTEM_WORKSPACE_BRANCH="$WT_BRANCH"
              SYSTEM_ACTIVE_DIR="$SYSTEM_ROOT"
              SYSTEM_ROOT="$MAIN_PATH"
            fi
          fi
        fi
      fi
    fi

    # Write per-session env file (always set all vars — blank when no workspace)
    cat > "$SESSION_DIR/$SESSION_ID.sh" <<EOF
export SYSTEM_ROOT="$SYSTEM_ROOT"
export SYSTEM_ACTIVE_DIR="$SYSTEM_ACTIVE_DIR"
export SYSTEM_WORKSPACE_NAME="$SYSTEM_WORKSPACE_NAME"
export SYSTEM_WORKSPACE_BRANCH="$SYSTEM_WORKSPACE_BRANCH"
EOF

    ;;

  PreToolUse)
    echo "export CLAUDE_SESSION_ID='$SESSION_ID'" > "$ENV_FILE"
    ;;

  SessionEnd)
    [ -n "$SESSION_ID" ] && rm -f "$SESSION_DIR/$SESSION_ID.sh"
    ;;
esac
