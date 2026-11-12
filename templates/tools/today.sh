#!/bin/bash
# Write today's evidence to a file the AI can read.
out=~/ai-log/evidence-$(date +%F).md
mkdir -p ~/ai-log
{
  echo "## Commits today"
  git -C __PROJECT__ log --since=midnight --format='%h %s'
  echo
  echo "## Pull requests I touched today"
  gh pr list --repo __REPO__ --author "@me" --state all \
    --search "updated:>=$(date +%F)"
} > "$out"
echo "wrote $out"
