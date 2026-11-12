#!/bin/bash
# Install the "AI setup that learns" files stage by stage (ten stages across the three parts of the series).
# Safe to rerun: never overwrites an existing file, backs up any config it edits,
# and only adds JSON entries that are missing. Use --dry-run to see the plan first.
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
T="$here/templates"

root="$HOME/ai-context"; stages="1-10"; tools="both"; cli="claude"; cron=0; dry=0
project=""; repo=""; loop_project=""; team_notes=""

usage() {
  cat <<'EOF'
Usage: install.sh [options]
  --root DIR            context folder (default ~/ai-context)
  --stages LIST         stages to install, such as 1-10, 1-6 or 1,2,5 (default 1-10)
  --tools NAME          cursor, claude or both (default both)
  --project DIR         git project that today.sh reads commits from (stage 5)
  --repo OWNER/NAME     GitHub repository that today.sh lists pull requests from (stage 5)
  --cli NAME            claude or agent, the CLI the evening drafts use (stage 7, default claude)
  --cron                add the evening-drafts line to your crontab (stage 7)
  --loop-project DIR    project to receive GOAL.md, check.sh and loop.sh (stage 8)
  --team-notes DIR      shared repository that share-tips.sh writes to (stage 9)
  --dry-run             print what would change, change nothing
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --root) root="$2"; shift 2 ;;
    --stages) stages="$2"; shift 2 ;;
    --tools) tools="$2"; shift 2 ;;
    --project) project="$2"; shift 2 ;;
    --repo) repo="$2"; shift 2 ;;
    --cli) cli="$2"; shift 2 ;;
    --cron) cron=1; shift ;;
    --loop-project) loop_project="$2"; shift 2 ;;
    --team-notes) team_notes="$2"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 2 ;;
  esac
done

expand() { case "$1" in "~"|"~/"*) printf '%s' "$HOME${1#\~}" ;; *) printf '%s' "$1" ;; esac; }
tilde()  { case "$1" in "$HOME"/*) printf '~%s' "${1#$HOME}" ;; *) printf '%s' "$1" ;; esac; }
root="$(expand "$root")"; project="$(expand "$project")"
loop_project="$(expand "$loop_project")"; team_notes="$(expand "$team_notes")"

case "$tools" in cursor|claude|both) ;; *) echo "--tools must be cursor, claude or both"; exit 2 ;; esac
case "$cli" in claude|agent) ;; *) echo "--cli must be claude or agent"; exit 2 ;; esac
case "$root$project$loop_project$team_notes" in *" "*) echo "Paths with spaces are not supported."; exit 2 ;; esac
command -v jq >/dev/null || { echo "jq is required. Install it (brew install jq) and rerun."; exit 2; }
command -v git >/dev/null || { echo "git is required."; exit 2; }

rootref="$(tilde "$root")"
[ -n "$project" ] || project="$HOME/code/myproject"
[ -n "$repo" ] || repo="you/myproject"
[ -n "$team_notes" ] || team_notes="$HOME/code/team-notes"

want() {
  local part
  for part in ${stages//,/ }; do
    case "$part" in
      *-*) [ "$1" -ge "${part%-*}" ] && [ "$1" -le "${part#*-}" ] && return 0 ;;
      *) [ "$1" = "$part" ] && return 0 ;;
    esac
  done
  return 1
}
uses() { [ "$tools" = both ] || [ "$tools" = "$1" ]; }

manual=()
note()  { manual+=("$*"); }
say()   { printf '%s\n' "$*"; }
act()   { if [ "$dry" = 1 ]; then say "would: $*"; else say "done: $*"; fi; }

render() {
  sed -e "s#~/ai-context#$rootref#g" \
      -e "s#__PROJECT__#$(tilde "$project")#g" -e "s#__REPO__#$repo#g" \
      -e "s#__LOOP_PROJECT__#$(tilde "$loop_project")#g" -e "s#__TEAM_NOTES__#$(tilde "$team_notes")#g" "$1"
}

backup() {
  [ "$dry" = 1 ] && return
  if [ -f "$1" ] && [ ! -e "$1.bak-ai-setup" ]; then cp "$1" "$1.bak-ai-setup"; say "backup: $1.bak-ai-setup"; fi
}

put() {   # put TEMPLATE DEST [MODE]
  local src="$T/$1" dest="$2" mode="${3:-644}"
  if [ -e "$dest" ]; then
    if render "$src" | cmp -s - "$dest"; then say "ok: $dest"; else say "skip: $dest already exists and differs, left unchanged"; fi
    return
  fi
  act "create $dest"
  [ "$dry" = 1 ] && return
  mkdir -p "$(dirname "$dest")" && render "$src" > "$dest" && chmod "$mode" "$dest"
}

append() {   # append FILE MARKER TEMPLATE
  local file="$1" marker="$2" src="$T/$3"
  if [ -f "$file" ] && grep -qF -- "$marker" "$file"; then say "ok: $file has \"$marker\""; return; fi
  act "add \"$marker\" to $file"
  [ "$dry" = 1 ] && return
  case "$file" in "$root"/*) ;; *) backup "$file" ;; esac
  mkdir -p "$(dirname "$file")"
  { [ -s "$file" ] && echo; render "$src"; } >> "$file"
}

jqedit() {   # jqedit FILE FILTER [jq args...]
  local file="$1" filter="$2"; shift 2
  local cur new
  if [ -f "$file" ]; then cur="$(cat "$file")"; else cur='{}'; fi
  if ! new="$(printf '%s' "$cur" | jq "$@" "$filter" 2>/dev/null)"; then
    say "ERROR: $file is not valid JSON. Left unchanged; fix it and rerun."; return 1
  fi
  if [ "$(printf '%s' "$cur" | jq -S . 2>/dev/null)" = "$(printf '%s' "$new" | jq -S .)" ]; then say "ok: $file"; return; fi
  act "update $file"
  [ "$dry" = 1 ] && return
  mkdir -p "$(dirname "$file")"; backup "$file"; printf '%s\n' "$new" > "$file"
}

link() {   # link SRC DESTDIR
  local dest="$2/$(basename "$1")"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$1" ]; then say "ok: $dest"; return; fi
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then say "skip: $dest exists and is not a link, left unchanged"; return; fi
  act "link $dest -> $1"
  [ "$dry" = 1 ] && return
  mkdir -p "$2" && ln -sfn "$1" "$dest"
}

cursor_hook() {   # cursor_hook EVENT SCRIPT TIMEOUT [failClosed]
  local entry
  entry="$(jq -nc --arg c "./hooks/$2" --argjson t "$3" --arg fc "${4:-}" \
    '{command: $c, timeout: $t} + (if $fc == "failClosed" then {failClosed: true} else {} end)')"
  jqedit "$HOME/.cursor/hooks.json" \
    '.version = (.version // 1) | .hooks[$ev] = ((.hooks[$ev] // []) | if any(.[]; .command == $e.command) then . else . + [$e] end)' \
    --arg ev "$1" --argjson e "$entry"
}

mkdirs() {
  local d
  for d in "$@"; do
    [ -d "$d" ] && continue
    act "create folder $d"; [ "$dry" = 1 ] || mkdir -p "$d"
  done
}

always="$root/memory/always.md"
[ "$dry" = 1 ] && say "Dry run. Nothing will change."
say "Context folder: $root   Tools: $tools   Stages: $stages"

if want 1; then
  say ""; say "== Stage 1: context folder and always-loaded instructions"
  mkdirs "$root/memory" "$root/docs"
  if [ -d "$root/.git" ]; then say "ok: $root is a git repository"
  else act "git init $root"; [ "$dry" = 1 ] || git -C "$root" init -q; fi
  put memory/always.md "$always"
  uses claude && append "$HOME/.claude/CLAUDE.md" "@$rootref/memory/always.md" memory/claude-import.md
  if uses cursor && ! want 6; then
    note "Cursor: open Customize, go to Rules, add a User Rule, and paste $always. Stage 6 replaces this with a hook."
  fi
  note "Edit $always to hold the five to ten instructions you repeat most."
  note "Back up $root to a private remote: git remote add origin <url> && git push -u origin main"
fi

if want 2; then
  say ""; say "== Stage 2: teach once, tips and saved commands"
  mkdirs "$root/skills" "$root/tools"
  append "$always" "## Teach once" memory/teach-once.md
  put docs/tips.md "$root/docs/tips.md"
  put skills/review-diff.md "$root/skills/review-diff/SKILL.md"
  put tools/link-all.sh "$root/tools/link-all.sh" 755
fi

if want 3; then
  say ""; say "== Stage 3: handoffs and loaders"
  mkdirs "$root/handoffs"
  put skills/handoff.md "$root/skills/handoff/SKILL.md"
  note "Loaders: for each area you work in, write $root/docs/<area>.md and a skill like $T/skills/loader-example.md."
fi

if want 4; then
  say ""; say "== Stage 4: tip IDs, lint and checkup"
  append "$always" "## Tips" memory/tip-ids.md
  put tools/lint.sh "$root/tools/lint.sh" 755
  put skills/notes-checkup.md "$root/skills/notes-checkup/SKILL.md"
fi

if want 5; then
  say ""; say "== Stage 5: evidence"
  append "$always" "## Evidence" memory/evidence.md
  put tools/today.sh "$root/tools/today.sh" 755
  put skills/status-update.md "$root/skills/status-update/SKILL.md"
  [ "$repo" = "you/myproject" ] && note "today.sh uses placeholder project and repository. Edit $root/tools/today.sh."
fi

if want 6; then
  say ""; say "== Stage 6: guardrails and hooks"
  append "$always" "## Safety" memory/safety.md
  if uses claude; then
    jqedit "$HOME/.claude/settings.json" \
      '.permissions.deny = reduce $add[] as $r ((.permissions.deny // []); if any(.[]; . == $r) then . else . + [$r] end)' \
      --argjson add '["Bash(git push *)","Bash(rm -rf *)","Read(./.env)","Edit(./deploy/**)"]'
  fi
  if uses cursor; then
    mkdirs "$root/hooks"
    put hooks/guard.sh "$root/hooks/guard.sh" 755
    put hooks/session-start.sh "$root/hooks/session-start.sh" 755
    link "$root/hooks/guard.sh" "$HOME/.cursor/hooks"
    link "$root/hooks/session-start.sh" "$HOME/.cursor/hooks"
    cursor_hook beforeShellExecution guard.sh 5 failClosed
    cursor_hook sessionStart session-start.sh 10
    note "Cursor: if you pasted always.md into User Rules, delete that copy now."
    note "Cursor: keep the agent's command allowlist short (agent settings)."
  fi
  note "Give automation read-only credentials, never your own."
fi

if want 7; then
  say ""; say "== Stage 7: logging, evening drafts, morning approval"
  mkdirs "$root/hooks" "$root/prompts"
  put hooks/log-prompt.sh "$root/hooks/log-prompt.sh" 755
  if uses cursor; then
    link "$root/hooks/log-prompt.sh" "$HOME/.cursor/hooks"
    cursor_hook beforeSubmitPrompt log-prompt.sh 5
  fi
  if uses claude; then
    jqedit "$HOME/.claude/settings.json" \
      '.hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) | if any(.[]; any(.hooks[]?; .command == $c)) then . else . + [{hooks: [{type: "command", command: $c, timeout: 5}]}] end)' \
      --arg c "$root/hooks/log-prompt.sh"
  fi
  put prompts/draft-updates.md "$root/prompts/draft-updates.md"
  put "tools/evening-drafts.$cli.sh" "$root/tools/evening-drafts.sh" 755
  put skills/morning.md "$root/skills/morning/SKILL.md"
  append "$always" "## Posting" memory/posting.md
  line="45 16 * * 1-5  /bin/bash $root/tools/evening-drafts.sh >> $HOME/ai-log/cron.log 2>&1"
  if [ "$cron" = 1 ]; then
    if crontab -l 2>/dev/null | grep -qF "$root/tools/evening-drafts.sh"; then say "ok: crontab has evening-drafts"
    else act "add to crontab: $line"; [ "$dry" = 1 ] || { mkdir -p "$HOME/ai-log"; ( crontab -l 2>/dev/null; echo "$line" ) | crontab -; }; fi
  else
    note "To schedule the drafts, add this with crontab -e: $line"
  fi
  note "If the scheduled run can't log in, put the CLI's API key in ~/.ai-secrets (chmod 600). Never in the context folder."
fi

if want 8; then
  say ""; say "== Stage 8: gated loop kit"
  if [ -n "$loop_project" ]; then
    put loop/GOAL.md "$loop_project/GOAL.md"
    put loop/check.sh "$loop_project/check.sh" 755
    put loop/loop.sh "$loop_project/loop.sh" 755
    note "Loop: smoke-test check.sh and loop.sh on a planted defect before any real run (part 3, "Only loop what a machine can judge")."
  else
    say "skip: no --loop-project given"
  fi
fi

if want 9; then
  say ""; say "== Stage 9: shared notes for cloud agents"
  put tools/share-tips.sh "$root/tools/share-tips.sh" 755
  [ -d "$team_notes/.git" ] || note "share-tips.sh writes to $team_notes, which is not a git repository yet. Create or clone it first."
  note "Give cloud agents read-only tokens, and keep a git copy of any prompt that lives in a dashboard."
fi

if want 10; then
  say ""; say "== Stage 10: the correction ladder"
  if [ -f "$root/skills/notes-checkup/SKILL.md" ] || [ "$dry" = 1 ]; then
    append "$root/skills/notes-checkup/SKILL.md" "correction ladder" skills/notes-checkup-climb.md
  else
    say "skip: notes-checkup is not installed (stage 4)"
  fi
  note "Make your first automatic skill: a SKILL.md without disable-model-invocation and with a specific description."
fi

if [ -f "$root/tools/link-all.sh" ] || { [ "$dry" = 1 ] && want 2; }; then
  say ""; act "run $root/tools/link-all.sh"
  [ "$dry" = 1 ] || bash "$root/tools/link-all.sh" >/dev/null
fi

if [ "${#manual[@]}" -gt 0 ]; then
  say ""; say "== Steps left for you"
  for m in "${manual[@]}"; do say "- $m"; done
fi
