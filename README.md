# build-ai-setup

A skill for Cursor and Claude Code that builds the setup from the 3-part series "Building an AI setup that learns":

1. **Memory.** A git context folder with always-loaded instructions, saved commands and notes the AI searches before solving a problem.
2. **Trust.** Tips with IDs that show where they're wrong, an evidence rule, and guardrail hooks the tools enforce.
3. **Automation.** Evening status drafts you approve each morning, gated agent loops, and shared notes.

## Install

```bash
git clone https://github.com/stephensamiya/build-ai-setup ~/.claude/skills/build-ai-setup
```

Cursor reads `~/.claude/skills` too. If you only use Cursor, clone into `~/.cursor/skills/build-ai-setup` instead.

Open a new chat and type `/build-ai-setup`. The agent asks which tools and stages you want, shows a dry run, installs after you approve, personalizes `always.md` with you, and runs the checks.

## Requirements

- `git` and `jq` (recent macOS includes `jq`; otherwise `brew install jq`)
- Cursor, Claude Code, or both
- Optional: the `claude` or `agent` CLI for the evening drafts and loops, and `gh` for pull request lists

## Run it without the agent

```bash
cd ~/.claude/skills/build-ai-setup
bash scripts/install.sh --stages 1-6 --dry-run
bash scripts/install.sh --stages 1-6
bash scripts/verify.sh
```

Run `bash scripts/install.sh --help` for every option. Stages 1 to 3 are part 1, 4 to 6 are part 2, and 7 to 10 are part 3. Start with 1 to 6; stages 7 to 9 run things unattended.

## What it changes

- Creates the context folder (default `~/ai-context`) and links its skills into `~/.cursor/skills` and `~/.claude/skills`.
- Merges entries into `~/.cursor/hooks.json` and `~/.claude/settings.json`, and adds an import line to `~/.claude/CLAUDE.md`.
- Never overwrites an existing file. Every config it edits is backed up to `<file>.bak-ai-setup`, so restoring that copy undoes the edit.
- Never pushes, never adds a git remote, and edits your crontab only with `--cron`.
- Never writes API keys. If a scheduled run needs one, put it in `~/.ai-secrets` yourself and `chmod 600` it.
