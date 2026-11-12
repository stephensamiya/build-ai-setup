#!/bin/bash
# Link every skill in ~/ai-context into Cursor and Claude Code.
src=~/ai-context/skills
for dest in ~/.cursor/skills ~/.claude/skills; do
  mkdir -p "$dest"
  for d in "$src"/*/; do
    [ -d "$d" ] || continue
    ln -sfn "${d%/}" "$dest/"
  done
done
echo "linked"
