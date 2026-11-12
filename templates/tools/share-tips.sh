#!/bin/bash
# Copy tips marked "share: yes" into the team repository and commit locally.
awk '/^### /{if(keep) printf "%s", buf; buf=""; keep=0}
     /^share: yes/{keep=1}
     /^### /,0{buf=buf $0 "\n"}
     END{if(keep) printf "%s", buf}' \
  ~/ai-context/docs/tips.md > __TEAM_NOTES__/tips.md
git -C __TEAM_NOTES__ add tips.md
git -C __TEAM_NOTES__ commit -m "Sync shared tips" && echo "Review the commit, then push."
