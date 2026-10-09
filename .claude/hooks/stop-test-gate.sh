#!/bin/bash
# Stop-gate: blokkerer økt-avslutning hvis raske tester for berørte flater er røde.
# Exit 2 = blokker Stop (stderr vises til Claude); exit 0 = slipp.
# iOS-simulatorrunden er BEVISST utenfor gaten (minutter) — reviewer/CI dekker den.
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

# Ikke løkk: hvis gaten allerede har blokkert én gang i denne stoppsekvensen, slipp.
if python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin).get("stop_hook_active") else 1)' 2>/dev/null; then
  exit 0
fi

changed=$(git diff --name-only HEAD 2>/dev/null; git status --porcelain 2>/dev/null | awk '{print $2}')
[ -z "$changed" ] && exit 0

fail=""

if echo "$changed" | grep -q '^apple/AppCore/'; then
  if ! out=$(PATH="$HOME/.local/share/swiftly/bin:$PATH" swift test --package-path apple/AppCore 2>&1 | tail -15); then
    fail="$fail\n--- AppCore (swift test) RØD ---\n$out"
  fi
fi

if echo "$changed" | grep -qE '^(server|packages/shared)/'; then
  if ! out=$(cd server && "$HOME/.bun/bin/bun" test 2>&1 | tail -15); then
    fail="$fail\n--- Server (bun test) RØD ---\n$out"
  fi
fi

if echo "$changed" | grep -qE '^(web|packages/shared)/'; then
  if ! out=$(cd web && "$HOME/.bun/bin/bun" run build 2>&1 | tail -15); then
    fail="$fail\n--- Web (next build) RØD ---\n$out"
  fi
fi

if [ -n "$fail" ]; then
  echo -e "Testgate: røde tester for berørte flater — fiks før du avslutter.$fail" >&2
  exit 2
fi
exit 0
