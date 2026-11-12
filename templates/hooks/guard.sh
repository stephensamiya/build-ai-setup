#!/bin/bash
# Cursor beforeShellExecution hook: deny risky shell commands.
command -v jq >/dev/null || exit 2   # exit code 2 tells Cursor to block
cmd="$(jq -r '.command // empty')"
case "$cmd" in
  *"git push"*|*"rm -rf"*)
    echo '{"permission":"deny","user_message":"Blocked by guard.sh","agent_message":"This command is not allowed. Ask the user to run it."}' ;;
  *)
    echo '{"permission":"allow"}' ;;
esac
