#!/bin/bash
# Check an installed "AI setup that learns" without changing it. Prints PASS, FAIL or SKIP per check.
# Exit code: 0 if nothing failed, 1 otherwise.
set -u

root="$HOME/ai-context"; tools="both"
while [ $# -gt 0 ]; do
  case "$1" in
    --root) root="$2"; shift 2 ;;
    --tools) tools="$2"; shift 2 ;;
    *) echo "Usage: verify.sh [--root DIR] [--tools cursor|claude|both]"; exit 2 ;;
  esac
done
case "$root" in "~"|"~/"*) root="$HOME${root#\~}" ;; esac
rootref="$root"; case "$root" in "$HOME"/*) rootref="~${root#$HOME}" ;; esac
uses() { [ "$tools" = both ] || [ "$tools" = "$1" ]; }

fails=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; fails=$((fails+1)); }
skip() { echo "SKIP  $1"; }
check() { if eval "$2" >/dev/null 2>&1; then pass "$1"; else fail "$1"; fi; }

command -v jq >/dev/null || { echo "FAIL  jq is not installed"; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

echo "== Stage 1"
check "context folder is a git repository" '[ -d "$root/.git" ]'
check "memory/always.md exists and is not empty" '[ -s "$root/memory/always.md" ]'
if uses claude; then
  check "~/.claude/CLAUDE.md imports always.md" 'grep -qxF "@$rootref/memory/always.md" "$HOME/.claude/CLAUDE.md" || grep -qxF "@$root/memory/always.md" "$HOME/.claude/CLAUDE.md"'
fi
n=$(wc -l < "$root/memory/always.md" 2>/dev/null || echo 0)
[ "$n" -le 100 ] && pass "always.md is $n lines (keep it under about 100)" || fail "always.md is $n lines; move area context and facts out (part 1, "Keep context small")"

echo "== Stage 2 and later: saved commands"
if [ -d "$root/skills" ]; then
  for f in "$root"/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    d="$(basename "$(dirname "$f")")"
    check "skill $d: name matches folder" 'grep -qx "name: $d" "$f"'
    check "skill $d: has a description" 'grep -q "^description: ." "$f"'
    for dest in "$HOME/.cursor/skills" "$HOME/.claude/skills"; do
      check "skill $d: linked in $dest" '[ -L "$dest/$d" ] && [ -f "$dest/$d/SKILL.md" ]'
    done
  done
else
  skip "no skills folder"
fi
broken="$(find "$HOME/.cursor/skills" "$HOME/.claude/skills" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null)"
[ -z "$broken" ] && pass "no broken skill links" || fail "broken skill links: $(echo $broken)"

echo "== Stage 4: notes"
if [ -x "$root/tools/lint.sh" ]; then
  out="$(bash "$root/tools/lint.sh" 2>&1)"
  [ -z "$out" ] && pass "lint.sh finds no broken links" || fail "lint.sh reports: $(echo "$out" | head -3 | tr '\n' ' ')"
else skip "lint.sh not installed"; fi

echo "== Stage 6: guardrails"
if uses claude && [ -f "$HOME/.claude/settings.json" ]; then
  check "~/.claude/settings.json is valid JSON" 'jq -e . "$HOME/.claude/settings.json"'
  check "Claude Code denies git push" 'jq -e "(.permissions.deny // []) | index(\"Bash(git push *)\")" "$HOME/.claude/settings.json"'
else skip "Claude Code settings"; fi
if uses cursor && [ -f "$HOME/.cursor/hooks.json" ]; then
  check "~/.cursor/hooks.json is valid JSON with version 1" 'jq -e ".version == 1" "$HOME/.cursor/hooks.json"'
  for c in $(jq -r '.hooks[]?[]?.command' "$HOME/.cursor/hooks.json" 2>/dev/null); do
    case "$c" in ./*) p="$HOME/.cursor/${c#./}" ;; *) p="$c" ;; esac
    check "Cursor hook $c exists and is executable" '[ -x "$p" ]'
  done
  g="$HOME/.cursor/hooks/guard.sh"
  if [ -x "$g" ]; then
    check "guard denies git push" '[ "$(echo "{\"command\":\"git push origin main\"}" | "$g" | jq -r .permission)" = deny ]'
    check "guard allows ls" '[ "$(echo "{\"command\":\"ls\"}" | "$g" | jq -r .permission)" = allow ]'
    check "guard entry has failClosed" 'jq -e "any(.hooks.beforeShellExecution[]?; .command == \"./hooks/guard.sh\" and .failClosed == true)" "$HOME/.cursor/hooks.json"'
  else skip "guard hook"; fi
  s="$HOME/.cursor/hooks/session-start.sh"
  if [ -x "$s" ]; then
    check "session-start hook returns always.md" '[ "$(echo "{}" | "$s" | jq -r .additional_context)" = "$(cat "$root/memory/always.md")" ]'
  else skip "session-start hook"; fi
else skip "Cursor hooks"; fi

echo "== Stage 7: logging and drafts"
lp="$root/hooks/log-prompt.sh"
if [ -x "$lp" ]; then
  r="$(echo '{"hook_event_name":"beforeSubmitPrompt","prompt":"verify","workspace_roots":["/x/proj"]}' | HOME="$tmp" "$lp")"
  check "log-prompt replies continue to Cursor" '[ "$(echo "$r" | jq -r .continue)" = true ]'
  check "log-prompt writes a log line" 'grep -q "	proj	verify$" "$tmp/ai-log/$(date +%F).log"'
  if uses claude && [ -f "$HOME/.claude/settings.json" ]; then
    check "Claude Code UserPromptSubmit hook points to log-prompt.sh" 'jq -e --arg c "$lp" "any(.hooks.UserPromptSubmit[]?.hooks[]?; .command == \$c)" "$HOME/.claude/settings.json"'
  fi
else skip "logging hook"; fi
if [ -x "$root/tools/evening-drafts.sh" ]; then
  cli="$(grep -oE '^(claude|agent) -p' "$root/tools/evening-drafts.sh" | cut -d' ' -f1)"
  check "evening-drafts CLI ($cli) is on PATH" 'command -v "$cli"'
  check "drafting prompt exists" '[ -s "$root/prompts/draft-updates.md" ]'
  if crontab -l 2>/dev/null | grep -qF "$root/tools/evening-drafts.sh"; then pass "crontab runs evening-drafts.sh"
  else skip "evening-drafts.sh is not in crontab"; fi
else skip "evening drafts"; fi

echo
[ "$fails" = 0 ] && echo "All checks passed." || echo "$fails check(s) failed."
[ "$fails" = 0 ]
