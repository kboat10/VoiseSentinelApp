#!/bin/sh
# Install git hooks for auto-sync (pull + push on commit)
set -e
cd "$(dirname "$0")/.."
hooks_src="scripts/git-hooks"
hooks_dst=".git/hooks"
for f in post-commit; do
  if [ -f "$hooks_src/$f" ]; then
    cp "$hooks_src/$f" "$hooks_dst/$f"
    chmod +x "$hooks_dst/$f"
    echo "Installed $f"
  fi
done
echo "Hooks installed. Commits will auto-push to origin."
