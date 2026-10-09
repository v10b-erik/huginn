#!/bin/bash
# Kjør en kommando under riggens låser. Laget for ssh-bruk fra ygg, der bygget
# skjer i ETT fjernkall og derfor ikke kan holde en lås fra mac-test.sh:
#
#   ssh draupnir "cd build/$WT && bash Scripts/wt-run.sh --slot 2 -- xcodebuild …"
#   ssh draupnir "cd build/$WT && bash Scripts/wt-run.sh --lock devrig-signing -- …"
#
# Låsen slippes av EXIT-trapen i wt-lib.sh. Derfor kjøres kommandoen IKKE med
# exec — exec ville byttet ut skallet og latt låsen bli stående.
set -euo pipefail
SD="$(cd "$(dirname "$0")" && pwd)"
cd "$SD/.."
. "$SD/wt-lib.sh"

LOCK=""
SLOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --lock) LOCK="$2"; shift 2 ;;
    --slot) SLOT="$2"; shift 2 ;;
    --)     shift; break ;;
    *)      echo "wt-run.sh: ukjent flagg $1" >&2; exit 64 ;;
  esac
done

if [ -n "$LOCK" ]; then wt_lock "$LOCK"; fi
if [ -n "$SLOT" ]; then wt_slot bygg "$SLOT"; fi

"$@"
