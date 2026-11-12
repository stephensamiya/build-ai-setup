#!/bin/bash
# Cursor sessionStart hook: add always.md to every new chat.
cat > /dev/null   # read and ignore the event details
jq -n --arg c "$(cat ~/ai-context/memory/always.md)" '{additional_context: $c}'
