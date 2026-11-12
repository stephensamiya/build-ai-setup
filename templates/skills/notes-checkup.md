---
name: notes-checkup
description: Weekly health check of my context folder.
disable-model-invocation: true
---
1. Run `bash ~/ai-context/tools/lint.sh` and list its findings.
2. Find claims about current state ("now", "currently", "is enabled") with no
   date, and claims dated more than six months ago.
3. Find files nothing links to, and TIP ids mentioned in handoffs that don't
   exist in docs/tips.md.
Report as a list with file and line. Writes: nothing.
