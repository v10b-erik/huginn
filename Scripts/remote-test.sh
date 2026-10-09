#!/bin/bash
# Kjøres PÅ ygg-v1: Scripts/remote-test.sh [core|ios|mac|device]
# Synker repoet til draupnir (rsync = synkron barriere) og kjører mac-test.sh der.
set -euo pipefail
SD="$(cd "$(dirname "$0")" && pwd)"
cd "$SD/.."
. "$SD/wt-lib.sh"
REMOTE="${REMOTE:-draupnir}"

# Alt som kan kollidere mellom parallelle worktrees nøkles på denne: byggmappa
# her, DerivedData og simulatoren på draupnir. Hovedtreet beholder produkt-
# navnet; en worktree får <produkt>-<branch>. Basename på $PWD holder IKKE —
# Claude Codes worktrees ligger i .claude/worktrees/<branch>, og da hadde to
# produkter med samme branchnavn rsync-et --delete over hverandre.
WT="$(wt_key)"
DEST="build/$WT"

ssh -o LogLevel=ERROR "$REMOTE" "mkdir -p $DEST"
rsync -az --delete \
  --exclude .git --exclude .build --exclude '*.xcodeproj' --exclude DerivedData \
  --exclude node_modules --exclude .next --exclude '.claude/worktrees' \
  ./ "$REMOTE:$DEST/"
# Bak git-sha inn i byggetreet (BuildInfo vises på alle skjermer — avgjørende
# for flerklient-feilsøking; se 21.09 lærdomsdokument). Kun draupnir-kopien.
SHA="$(git rev-parse --short HEAD 2>/dev/null || echo ukjent)$(git diff --quiet 2>/dev/null || echo '*')"
ssh -o LogLevel=ERROR "$REMOTE" "cd $DEST && sed -i '' 's|BUILD_VERSION_PLACEHOLDER|$SHA $(date +%H:%M)|' apple/AppCore/Sources/AppCore/BuildInfo.swift"
ssh -o LogLevel=ERROR "$REMOTE" "cd $DEST && DEVRIG_WT=$WT bash Scripts/mac-test.sh ${1:-core}"
