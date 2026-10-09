#!/bin/bash
# Kjøres PÅ draupnir. Skriver UDID-en til DENNE worktreens EGEN simulator på
# stdout, og oppretter den hvis den ikke finnes (arver enhetstype og runtime
# fra nyeste tilgjengelige iPhone-simulator).
#
# Hvorfor ikke bare «første ledige iPhone»: to worktrees som gjør det lander på
# samme simulator og overskriver hverandres app-container. Testdata forsvinner,
# og et skjermbilde kan vise nabo-agentens tilstand. Feilen er stille — det er
# derfor den er farlig.
#
# Bundle-ID-en holdes UENDRET på tvers av worktrees med vilje: å suffikse den
# ville brutt provisjonering på device-sporet. Isolasjonen ligger i simulatoren.
#
#   Scripts/wt-sim.sh [worktree-nøkkel]     # default: mappenavnet
set -euo pipefail
export PATH="/opt/homebrew/bin:$PATH"

WT="${1:-$(basename "$PWD")}"
NAVN="sim-$WT"

UDID="$(xcrun simctl list devices --json | /usr/bin/python3 -c '
import json, sys
navn = sys.argv[1]
for _runtime, enheter in json.load(sys.stdin)["devices"].items():
    for d in enheter:
        if d["name"] == navn and d.get("isAvailable", True):
            print(d["udid"]); sys.exit(0)
' "$NAVN" || true)"

if [ -z "$UDID" ]; then
  MAL="$(xcrun simctl list devices available --json | /usr/bin/python3 -c '
import json, sys
data = json.load(sys.stdin)["devices"]
for runtime in sorted(data, reverse=True):
    if "SimRuntime.iOS-" not in runtime:
        continue
    for d in data[runtime]:
        if d["name"].startswith("iPhone") and d.get("deviceTypeIdentifier"):
            print(d["deviceTypeIdentifier"], runtime); sys.exit(0)
sys.exit(1)')"
  # $MAL er «enhetstype runtime» og skal ordsplittes.
  # shellcheck disable=SC2086
  UDID="$(xcrun simctl create "$NAVN" $MAL)"
  echo "== opprettet simulator $NAVN ($MAL) ==" >&2
fi

echo "$UDID"
