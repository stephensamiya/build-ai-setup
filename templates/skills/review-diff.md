---
name: review-diff
description: Review my uncommitted changes before I commit.
disable-model-invocation: true
---
# Review my changes

Input: an optional focus typed after the command, such as "/review-diff security".

Steps:
1. Run `git diff` and read every changed file in full.
2. Check for missing tests, unhandled errors, leftover debug code and secrets.
3. List findings, most serious first, with file and line.

Writes: nothing.
Never: commit, push, or edit files.
