#!/bin/bash
# Synsløkka for iOS (kjøres PÅ ygg-v1, etter `Scripts/remote-test.sh ios` som har bygd appen på draupnir):
#   Scripts/ios-shot.sh <utfil.png> <mork|lys> [launch-argumenter …]
# Installerer sist bygde App.app på worktreens EGEN simulator, setter utseende, starter med argumentene
# (f.eks. --demo --fane=traader), venter og henter ett skjermbilde. Bare syntetisk demo-innhold.
set -euo pipefail
SD="$(cd "$(dirname "$0")" && pwd)"
cd "$SD/.."
. "$SD/wt-lib.sh"
UT="$1"; UTSEENDE="$2"; shift 2
REMOTE="${REMOTE:-draupnir}"
WT="$(wt_key)"
VENT="${VENT:-3}"
ssh -o LogLevel=ERROR "$REMOTE" "export PATH=/opt/homebrew/bin:\$PATH; set -e
  cd build/$WT
  UDID=\$(bash Scripts/wt-sim.sh $WT)
  xcrun simctl bootstatus \$UDID -b >/dev/null
  xcrun simctl status_bar \$UDID override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true
  xcrun simctl ui \$UDID appearance $([ "$UTSEENDE" = mork ] && echo dark || echo light)
  xcrun simctl terminate \$UDID no.huginn.App >/dev/null 2>&1 || true
  xcrun simctl install \$UDID /tmp/dd-$WT/Build/Products/Debug-iphonesimulator/App.app
  xcrun simctl launch \$UDID no.huginn.App $* >/dev/null
  sleep $VENT
  xcrun simctl io \$UDID screenshot /tmp/shot-$WT.png >/dev/null 2>&1"
scp -q -o LogLevel=ERROR "$REMOTE:/tmp/shot-$WT.png" "$UT"
