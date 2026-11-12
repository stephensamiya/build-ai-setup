#!/bin/bash
# Run up to five fresh agent sessions until check.sh passes. Never pushes.
branch="${1:-loop/work}"
cd __LOOP_PROJECT__ || exit 2
git switch "$branch" 2>/dev/null || git switch -c "$branch" || exit 2
fingerprint() { find tests check.sh GOAL.md -type f -exec shasum {} + | sort | shasum; }
guard="$(fingerprint)"

for i in 1 2 3 4 5; do
  claude -p "$(cat GOAL.md)" --permission-mode dontAsk \
    --allowedTools "Read" "Edit" "Write" "Bash(npm test *)" "Bash(ls *)" \
      "Bash(git log *)" "Bash(git diff *)" "Bash(git add *)" "Bash(git commit *)"
  if [ "$(fingerprint)" != "$guard" ]; then
    echo "STOP: protected files were modified"; exit 1
  fi
  ./check.sh; rc=$?
  case $rc in
    0) echo "PASS after session $i"; exit 0 ;;
    2) echo "STOP: setup error, fix the environment"; exit 2 ;;
  esac
done
echo "STOP: no pass after 5 sessions"; exit 1
