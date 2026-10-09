#!/bin/bash
# PreToolUse-gate på Bash-kall: nekter kjente destruktive mønstre.
# Exit 2 + deny-JSON = blokkert; exit 0 = slipp gjennom.
set -euo pipefail

cmd=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))')

deny() {
  python3 -c "import json; print(json.dumps({'hookSpecificOutput':{'hookEventName':'PreToolUse','permissionDecision':'deny','permissionDecisionReason':'$1'}}))"
  exit 2
}

case "$cmd" in
  *"rm -rf /"*|*"rm -rf ~"*|*"rm -rf .."*)
    deny "Destruktiv sletting utenfor arbeidsområdet er blokkert." ;;
esac

if echo "$cmd" | grep -qiE 'git push[^|;&]*(--force|-f )[^|;&]*(origin|platform)[^|;&]*(main|master)'; then
  deny "Force-push til main er blokkert - bruk vanlig push eller ta det manuelt."
fi

if echo "$cmd" | grep -qiE '\b(drop (table|database|schema)|truncate table)\b'; then
  deny "Destruktiv SQL (DROP/TRUNCATE) er blokkert i agentkjoring - kjor migrasjoner eksplisitt."
fi

if echo "$cmd" | grep -qE 'security (delete-keychain|set-keychain-settings)|\.appstoreconnect/private_keys'; then
  deny "Keychain-oppsett og signeringsnokler rores ikke av agenter - se AGENTS.md."
fi

exit 0
