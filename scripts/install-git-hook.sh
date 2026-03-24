#!/usr/bin/env bash
set -e

HOOK_PATH=".git/hooks/post-commit"
ORACLE_SCRIPTS_DIR=".product-oracle/scripts"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

HOOK_BLOCK='
# -- codebase-oracle staleness check --
ORACLE_DIR=".product-oracle"
if [ -d "$ORACLE_DIR" ] && [ -f "$ORACLE_DIR/.staleness.json" ]; then
  CHANGED=$(git diff --name-only HEAD~1 HEAD 2>/dev/null)
  if [ -n "$CHANGED" ]; then
    python3 "$ORACLE_DIR/scripts/check-staleness.py" $CHANGED 2>/dev/null || true
  fi
fi
'

# Validate we are in a git repo
if [ ! -d ".git" ]; then
  echo "Error: not a git repository. Run this from your project root." >&2
  exit 1
fi

# Install or append the hook
if [ -f "$HOOK_PATH" ]; then
  # Check if oracle block is already present
  if grep -q "codebase-oracle staleness check" "$HOOK_PATH"; then
    echo "Oracle git hook already installed at $HOOK_PATH — skipping."
  else
    printf '%s' "$HOOK_BLOCK" >> "$HOOK_PATH"
    echo "Oracle staleness check appended to existing $HOOK_PATH"
  fi
else
  printf '#!/usr/bin/env bash\n%s' "$HOOK_BLOCK" > "$HOOK_PATH"
  echo "Oracle git hook installed at $HOOK_PATH"
fi

chmod +x "$HOOK_PATH"

# Copy check-staleness.py into the project's .product-oracle/scripts/
mkdir -p "$ORACLE_SCRIPTS_DIR"
cp "$SCRIPT_DIR/check-staleness.py" "$ORACLE_SCRIPTS_DIR/check-staleness.py"
echo "Staleness script copied to $ORACLE_SCRIPTS_DIR/check-staleness.py"
