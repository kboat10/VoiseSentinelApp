#!/bin/sh
# Manual sync: pull latest, then push any local commits.
# Run this anytime to get others' changes: ./scripts/sync.sh
set -e
cd "$(dirname "$0")/.."
branch=$(git branch --show-current)
echo "Pulling from origin/$branch..."
git pull --rebase origin "$branch" || git pull origin "$branch"
echo "Pushing to origin/$branch..."
git push origin "$branch"
echo "Sync complete."
