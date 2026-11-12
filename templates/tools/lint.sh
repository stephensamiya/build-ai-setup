#!/bin/bash
# Report links to local markdown files that don't exist.
cd ~/ai-context || exit 1
grep -rnoE '\]\([^)#]+\.md' --include='*.md' . | while IFS=: read -r file line link; do
  target="${link#](}"
  case "$target" in http*) continue ;; esac
  [ -e "$(dirname "$file")/$target" ] || echo "$file:$line -> missing $target"
done
