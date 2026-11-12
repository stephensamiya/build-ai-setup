---
name: build-ai-setup
description: Builds the "AI setup that learns" from scratch for Cursor and Claude Code. It creates a git context folder with always-loaded instructions, saved commands, tips with IDs, an evidence rule, guardrail hooks, prompt logging, evening drafts with morning approval, a gated loop kit and shared notes. Use when the user runs /build-ai-setup or asks to replicate or install this setup.
disable-model-invocation: true
---
# Build the AI setup that learns

This skill installs the system from the 10-part series "Building an AI setup that learns". Each install stage matches one part. `scripts/install.sh` does the file work: it creates files, links skills and hooks, and merges JSON configs. Your job is to interview the user, show the plan, run the script, personalize the files, and verify the result.

## Rules

- Make changes outside the context folder only through `scripts/install.sh`. It backs up every config it edits to `<file>.bak-ai-setup` and never overwrites an existing file.
- Never write API keys or passwords into any file. Tell the user where a key goes; they put it there.
- Never push, never edit the crontab, and never add a git remote unless the user says yes to that specific step.
- Show every edit to `always.md` before writing it.
- If a check fails, fix the cause. Never edit `verify.sh` to make a check pass.

## Progress checklist

Copy this and keep it updated:

```
- [ ] 1. Check prerequisites
- [ ] 2. Interview
- [ ] 3. Dry run, approved by the user
- [ ] 4. Install
- [ ] 5. Personalize always.md
- [ ] 6. Finish the steps left for the user
- [ ] 7. Run verify.sh until it passes
- [ ] 8. Test inside each tool
- [ ] 9. Commit the context folder
```

## 1. Check prerequisites

Run `command -v git jq claude agent gh` and `ls -d ~/.cursor ~/.claude`. `git` and `jq` are required. Recent macOS versions include `jq`; otherwise suggest `brew install jq`. Use the output to suggest which tools the user has.

## 2. Interview

Ask these questions, using a multiple-choice question tool if you have one:

1. Which tools: Cursor, Claude Code, or both? (Maps to `--tools cursor|claude|both`.)
2. Where should the context folder live? Default `~/ai-context`. (`--root`)
3. Which stages? Default all ten. Suggest 1 to 6 for a first evening, because 7 to 9 run things unattended. (`--stages`)
4. Stage 5: which local git project and which GitHub repository should `today.sh` read? Skip if they don't use GitHub. (`--project`, `--repo`)
5. Stage 7: should the evening drafts use `claude` or Cursor's `agent`? Should the script add the 4:45 PM weekday cron job, or will they add it later? (`--cli`, `--cron`)
6. Stage 8: is there a project with a test command where they want the loop kit? (`--loop-project`)
7. Stage 9: path to a shared team repository for safe tips, if any. (`--team-notes`)

## 3. Dry run

Run the script with the chosen options and `--dry-run`, from this skill's folder:

```bash
bash scripts/install.sh --tools both --stages 1-10 --project ~/code/app --repo me/app --cli claude --dry-run
```

Show the user the output. Lines starting with `would:` are changes, `skip:` means an existing file is kept as is, and `ok:` means nothing is needed. Ask for approval before continuing. If a `skip:` line covers a file the user wants replaced, they must move it aside themselves.

## 4. Install

Run the same command without `--dry-run`. Read the output. Fix any `ERROR:` line (usually invalid JSON in an existing config) and rerun. The script is safe to rerun.

## 5. Personalize always.md

The installed `memory/always.md` starts with example instructions. Ask the user for the five to ten things they repeat to an AI most often: answer style, commit and push rules, test commands, systems that are read-only. Rewrite the "Standing instructions" section with their answers, keep the sections the script added, show the diff, and write it after they agree. Keep the file under about 60 lines.

## 6. Finish the steps left for the user

The script ends with "Steps left for you". Go through each one:

- **Loaders (stage 3).** Ask which areas of work they switch between. For each area, draft `docs/<area>.md` with them, then create `skills/<area>/SKILL.md` from `templates/skills/loader-example.md`, replacing "billing". Run `tools/link-all.sh` afterwards.
- **Cursor User Rules (stage 1 without stage 6).** The user pastes `always.md` into Customize, then Rules, then User Rules. With stage 6 installed, the session-start hook does this, so they delete any pasted copy.
- **Placeholders.** If `today.sh` still shows `you/myproject`, ask for the real values and edit it.
- **Cron and API keys (stage 7).** If they declined `--cron`, show the crontab line. If a scheduled run fails to log in, tell them to create `~/.ai-secrets` with `export ANTHROPIC_API_KEY=...` or `export CURSOR_API_KEY=...` and run `chmod 600 ~/.ai-secrets`. They write the key, not you.
- **Loop kit (stage 8).** Walk them through the smoke test: run `./check.sh` on passing code (expect exit 0), plant a defect on a `smoke-test` branch (expect exit 1), then `bash loop.sh smoke-test` and expect "PASS after session 1". Don't start a real loop.
- **Remote backup.** Offer `git remote add origin <private-url>` and `git push -u origin main`. Run them only after a yes.

## 7. Verify

```bash
bash scripts/verify.sh --root ~/ai-context --tools both
```

Every line must be PASS or SKIP. A SKIP is fine for a stage the user didn't install. For each FAIL, find the cause, fix it, and rerun.

## 8. Test inside each tool

The scripts can't open a chat, so ask the user to do these in a new chat in each tool, and report back:

1. "What are my standing instructions about commits?" The answer should quote `always.md`.
2. Type `/review-diff`. It should run the saved command.
3. "Remember: always run the linter before committing." The AI should propose an edit and wait for a yes.
4. "Push this branch." The tool itself should block it, not just the AI declining. In Cursor, the message "Blocked by guard.sh" appears.
5. "Do the tests pass?" before running anything. The AI should say it hasn't checked.

If a test fails, restart the tool (hooks and rules load at startup), then check the matching stage's files.

## 9. Commit

```bash
cd ~/ai-context && git add -A && git commit -m "Build AI setup"
```

Tell the user what was installed, which stages were skipped, and where the backups are.

## Undo

Each edited config has a `.bak-ai-setup` copy next to it. Restore it to undo the edit. Links live in `~/.cursor/skills`, `~/.claude/skills` and `~/.cursor/hooks`; delete them to unlink. The context folder is a git repository, so `git log` shows everything else.

## Stages and parts

| Stage | Part | Installs |
|---|---|---|
| 1 | Files are the memory | Context folder, `memory/always.md`, `CLAUDE.md` import |
| 2 | Teach once | Teach-once rule, `docs/tips.md`, `/review-diff`, `tools/link-all.sh` |
| 3 | Context rot | `handoffs/`, `/handoff`, loader template |
| 4 | Trustworthy notes | Tip ID rules, `tools/lint.sh`, `/notes-checkup` |
| 5 | Evidence over memory | Evidence rule, `tools/today.sh`, `/status-update` |
| 6 | Guardrails | Safety rule, Claude Code deny rules, Cursor guard and session-start hooks |
| 7 | Status updates | Prompt logging hook, `prompts/draft-updates.md`, `tools/evening-drafts.sh`, `/morning`, optional cron job |
| 8 | Gated loops | `GOAL.md`, `check.sh`, `loop.sh` in the chosen project |
| 9 | Cloud or local | `tools/share-tips.sh` |
| 10 | Correction ladder | Weekly ladder step in `/notes-checkup` |
