---
name: handoff
description: Write a handoff file so a new chat can continue this work.
disable-model-invocation: true
---
Write a handoff for continuing this work in a new chat. Save it as
~/ai-context/handoffs/<today's date>-<short-slug>.md with these sections:
1. Goal
2. Current state, including the branch
3. Decisions and why
4. Dead ends: what failed, and why
5. Next step and the files involved
Leave out everything else. Keep it under 60 lines.
Writes: one file in ~/ai-context/handoffs/.
