#!/bin/bash
# Append one line per prompt to ~/ai-log/<date>.log. Never blocks anything.
input="$(cat)"
prompt="$(printf '%s' "$input" | jq -j '.prompt // empty' | tr '\n\t' '  ' | cut -c1-160)"
project="$(printf '%s' "$input" | jq -r '(.workspace_roots // [])[0] // .cwd // "unknown"' | xargs basename)"
mkdir -p ~/ai-log
printf '%s\tprompt\t%s\t%s\n' "$(date +%Y-%m-%dT%H:%M)" "$project" "$prompt" >> ~/ai-log/"$(date +%F)".log
[ "$(printf '%s' "$input" | jq -r '.hook_event_name // empty')" = "beforeSubmitPrompt" ] && echo '{"continue": true}'
exit 0
