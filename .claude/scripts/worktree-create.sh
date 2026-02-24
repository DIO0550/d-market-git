#!/usr/bin/env bash
set -euo pipefail

# Read JSON from stdin and extract name and cwd
INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name')
CWD=$(echo "$INPUT" | jq -r '.cwd')

WORKTREE_DIR="$CWD/.claude/worktrees/$NAME"

# Create worktree (progress output to stderr)
git worktree add --detach "$WORKTREE_DIR" >&2

# Copy files matching .worktreeinclude patterns
INCLUDE_FILE="$CWD/.worktreeinclude"
if [[ -f "$INCLUDE_FILE" ]]; then
  while IFS= read -r pattern || [[ -n "$pattern" ]]; do
    # Skip empty lines and comments
    [[ -z "$pattern" || "$pattern" == \#* ]] && continue

    # Use bash globbing to find matching files
    cd "$CWD"
    shopt -s nullglob dotglob
    files=($pattern)
    shopt -u nullglob dotglob

    for file in "${files[@]}"; do
      # Skip directories
      [[ -d "$file" ]] && continue
      rsync -aR "$file" "$WORKTREE_DIR/" >&2
    done
  done < "$INCLUDE_FILE"
fi

# Output the worktree path to stdout
echo "$WORKTREE_DIR"
