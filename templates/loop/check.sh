#!/bin/bash
# The gate. Exit 0: pass. Exit 1: the change is wrong. Exit 2: the setup is broken.
[ -d node_modules ] || { echo "SETUP ERROR: node_modules is missing. Run npm install."; exit 2; }
npm test >/dev/null 2>&1 || { echo "FAIL: npm test"; exit 1; }
echo "PASS"
