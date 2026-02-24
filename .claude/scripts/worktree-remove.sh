#!/usr/bin/env bash
set -euo pipefail

# Read JSON from stdin and extract worktree path
INPUT=$(cat)
WORKTREE_PATH=$(echo "$INPUT" | jq -r '.worktree_path')

# Remove the worktree
git worktree remove --force "$WORKTREE_PATH"
