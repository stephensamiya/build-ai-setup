#!/bin/bash
# Draft today's updates from today's records. Cron runs this on weekday evenings.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
[ -f ~/.ai-secrets ] && . ~/.ai-secrets
day=$(date +%F)
bash ~/ai-context/tools/today.sh
mkdir -p ~/ai-drafts
prompt="$(cat ~/ai-context/prompts/draft-updates.md)

# Evidence
$(cat ~/ai-log/evidence-"$day".md)

# Activity log
$(cat ~/ai-log/"$day".log 2>/dev/null)"

agent -p --mode ask --trust --workspace ~/ai-log "$prompt" > ~/ai-drafts/"$day".tmp \
  && mv ~/ai-drafts/"$day".tmp ~/ai-drafts/"$day".md
