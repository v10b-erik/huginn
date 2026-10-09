#!/bin/bash
# Livssyklus for parallelle worktrees — én feature per tre. Kjøres PÅ ygg-v1.
#
#   Scripts/wt.sh new <navn>    ny branch + worktree som søsken av repoet,
#                               kaldstartfiler kopiert, bun install kjørt
#   Scripts/wt.sh list          trærne her + byggmapper, simulatorer og låser
#                               på byggeverten
#   Scripts/wt.sh rm <navn>     river treet OG alt det eier på byggeverten
#   Scripts/wt.sh sweep         river alle trær hvis gren er merget i main
#                               (rene trær, aldri det du står i) og det de
#                               eier på byggeverten. Kjøres automatisk av
#                               Scripts/hooks/post-merge.
#
# Worktreen er gratis på ygg (bygget skjer på draupnir), men den eier tre ting
# på byggeverten: build/<nøkkel>, /tmp/dd-<nøkkel> og simulatoren sim-<nøkkel>.
# Opprydding er en del av kontrakten — ellers fylles disken på draupnir.
set -euo pipefail
SD="$(cd "$(dirname "$0")" && pwd)"
# Treet kommandoen ble startet FRA, målt før vi cd-er inn i skriptets eget tre.
# `sweep` bruker det til aldri å rive treet du står i — også når du kaller
# hovedtreets wt.sh fra en worktree (da er SD/.. hovedtreet, ikke der du er).
START_TRE="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$SD/.."
. "$SD/wt-lib.sh"

REMOTE="${REMOTE:-draupnir}"
GCD="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
HOVED="$(dirname "$GCD")"
PROD="$(basename "$HOVED")"

# Versjonerte hooks (Scripts/hooks/post-merge → `wt.sh sweep`). Settes her, ikke
# i en installasjonsrutine, så enhver klone som har kjørt wt.sh én gang har dem.
# 38 merga trær sto igjen på ygg-v1 2026-09-25 fordi «etter merge: wt.sh rm»
# var en setning i AGENTS.md og ikke en mekanisme.
if [ -z "$(git -C "$HOVED" config --get core.hooksPath)" ] && [ -d "$HOVED/Scripts/hooks" ]; then
  git -C "$HOVED" config core.hooksPath Scripts/hooks
fi

# Riv det et tre eier på byggeverten. Best effort: draupnir kan være av, og da
# skal ikke et lokalt fjernet tre etterlate en halvferdig kommando — `sweep`
# tar igjen foreldreløse byggmapper neste gang.
byggevert_rens() {  # <nøkkel>...
  [ $# -gt 0 ] || return 0
  local k liste=""
  for k in "$@"; do liste="$liste 'build/$k' '/tmp/dd-$k'"; done
  timeout 60 ssh -o LogLevel=ERROR -o ConnectTimeout=8 "$REMOTE" "
    export PATH=/opt/homebrew/bin:\$PATH
    rm -rf $liste
    for k in $*; do xcrun simctl delete \"sim-\$k\" 2>/dev/null || true; done
  " 2>/dev/null || echo "  ($REMOTE ikke nådd — byggmapper for: $* står igjen; wt.sh sweep tar dem senere)"
}

rens() { printf '%s' "$1" | tr '/ ' '--' | tr -cd 'A-Za-z0-9._-'; }

case "${1:-}" in
  new)
    NAVN="$(rens "${2:?bruk: Scripts/wt.sh new <navn>}")"
    WT="$PROD-$NAVN"
    DIR="$(cd "$HOVED/.." && pwd)/$WT"
    [ -e "$DIR" ] && { echo "finnes allerede: $DIR" >&2; exit 1; }

    git -C "$HOVED" worktree add -b "$NAVN" "$DIR"

    # Worktrees får bare sporede filer. Uten dette feiler agenten forvirrende
    # på manglende config — den vanligste worktree-fella i praksis.
    if [ -f "$HOVED/.worktreeinclude" ]; then
      while IFS= read -r m; do
        case "$m" in ''|'#'*) continue ;; esac
        for f in $m; do
          if [ -e "$HOVED/$f" ]; then
            mkdir -p "$DIR/$(dirname "$f")"
            cp -a "$HOVED/$f" "$DIR/$f"
            echo "  kopiert $f"
          fi
        done
      done <"$HOVED/.worktreeinclude"
    fi

    [ -f "$DIR/package.json" ] && (cd "$DIR" && bun install >/dev/null && echo "  bun install ok")

    # Egen port per tre, avledet av navnet — stabil, så den kan skrives i doc
    # og bokmerker. To worktrees skal aldri kjempe om 3011.
    PORT=$((10000 + $(printf '%s' "$NAVN" | cksum | cut -d' ' -f1) % 10000))
    if [ ! -f "$DIR/.env.local" ] || ! grep -q '^PORT=' "$DIR/.env.local" 2>/dev/null; then
      echo "PORT=$PORT" >>"$DIR/.env.local"
    fi

    echo
    echo "worktree:   $DIR"
    echo "nøkkel:     $WT   (build/$WT, /tmp/dd-$WT, sim-$WT på $REMOTE)"
    echo "web-port:   $PORT"
    echo "start:      cd $DIR && claude"
    if [ -d "$HOVED/server" ]; then
      echo
      echo "MERK: databasen deles med hovedtreet. Rører featuren migrasjoner,"
      echo "      pek DATABASE_URL i .env.local mot en egen db — ellers er"
      echo "      isolasjonen bare halv."
    fi
    ;;

  list)
    git -C "$HOVED" worktree list
    echo
    echo "== $REMOTE =="
    ssh -o LogLevel=ERROR "$REMOTE" '
      export PATH="/opt/homebrew/bin:$PATH"
      echo "-- byggmapper --"; du -sh build/*/ 2>/dev/null || echo "  (ingen)"
      echo "-- DerivedData --"; du -sh /tmp/dd-* 2>/dev/null || echo "  (ingen)"
      echo "-- simulatorer --"; xcrun simctl list devices | grep -E "^ +sim-" || echo "  (ingen)"
      echo "-- låser --"; ls -d /tmp/devrig-lock-* /tmp/devrig-slot-* 2>/dev/null || echo "  (ingen)"
    '
    ;;

  rm)
    NAVN="$(rens "${2:?bruk: Scripts/wt.sh rm <navn>}")"
    WT="$PROD-$NAVN"
    [ -n "$NAVN" ] || { echo "tomt navn" >&2; exit 1; }
    DIR="$(cd "$HOVED/.." && pwd)/$WT"

    git -C "$HOVED" worktree remove ${FORCE:+--force} "$DIR"
    git -C "$HOVED" branch -d "$NAVN" 2>/dev/null ||
      echo "  branchen $NAVN er ikke merget — beholdt (slett med git branch -D $NAVN)"

    byggevert_rens "$WT"
    echo "revet: $DIR + build/$WT + /tmp/dd-$WT + sim-$WT"
    ;;

  sweep)
    # Et tre rives når (1) grenen er merget i main, (2) treet er rent, og (3) det
    # ikke er treet vi står i. Grenen slettes med -d, som nekter hvis noe likevel
    # ikke er merget — belte og bukseseler. Trær som ikke kvalifiserer listes,
    # så det er synlig hva som står igjen og hvorfor.
    HER="$START_TRE"
    revet=""; levende="$PROD"
    while IFS= read -r line; do
      case "$line" in worktree\ *) ;; *) continue ;; esac
      TRE="${line#worktree }"
      [ "$TRE" = "$HOVED" ] && continue
      BR="$(git -C "$TRE" branch --show-current 2>/dev/null || true)"
      KEY="$(printf '%s' "$PROD-${BR:-detached}" | tr '/ ' '--' | tr -cd 'A-Za-z0-9._-')"
      if [ "$TRE" = "$HER" ]; then
        echo "  står igjen (du står i det):      $TRE"; levende="$levende $KEY"; continue
      fi
      if [ -z "$BR" ]; then
        echo "  står igjen (løsrevet HEAD):      $TRE"; levende="$levende $KEY"; continue
      fi
      if [ -n "$(git -C "$TRE" status --porcelain 2>/dev/null)" ]; then
        echo "  står igjen (uforpliktede endr.): $TRE"; levende="$levende $KEY"; continue
      fi
      if ! git -C "$HOVED" merge-base --is-ancestor "$BR" main 2>/dev/null; then
        echo "  står igjen (ikke merget i main): $TRE"; levende="$levende $KEY"; continue
      fi
      git -C "$HOVED" worktree remove "$TRE" && git -C "$HOVED" branch -d "$BR" >/dev/null 2>&1 || true
      echo "  revet: $TRE ($BR)"
      revet="$revet $KEY"
    done < <(git -C "$HOVED" worktree list --porcelain)
    git -C "$HOVED" worktree prune

    # Byggeverten: riv nøklene vi nettopp fjernet. Bevisst IKKE «alt under
    # build/<produkt>-* uten levende tre»: den regelen traff build/v10b-device og
    # build/v10b-verify første gang den kjørte (2026-09-25) — byggvarianter som
    # deler prefiks med worktree-nøklene uten å være det. Rester etter trær revet
    # mens draupnir var av tas med `wt.sh list` + `wt.sh rm`-hjelperen for hånd.
    # shellcheck disable=SC2086
    byggevert_rens $revet
    [ -n "$revet" ] && echo "ryddet på $REMOTE:$revet" || echo "  ingenting å rive"
    ;;

  *)
    sed -n '2,16p' "$0"
    exit 64
    ;;
esac
