#!/bin/bash
# Koble repoet til JD-briefen i ~/basic. Kjøres PÅ ygg-v1 fra repo-rot.
#
#   Scripts/jd-kobling.sh           # koble (idempotent)
#   Scripts/jd-kobling.sh --sjekk   # bare se; exit 0 = koblet, 1 = ikke
#
# Tre ting, alle styrt av `.ygg-jd`:
#   1. CLAUDE.md importerer JD-mappas AGENTS.md — Nåtilstand og planene er
#      fasit der, og en økt i repoet så dem ikke før.
#   2. JD-mappa er `additionalDirectories` i .claude/settings.json, så økta kan
#      lese og skrive plan-/loggfilene uten å stå i JD-mappa.
#   3. JD-mappa får en SessionStart-hook som minner om `p <produkt>`. Startes
#      `claude` der, lastes ikke repoets agenter, skills eller Stop-gaten
#      (målt 2026-10-08: 97 % av v10b-kallene hadde cwd i JD-mappa).
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)/.."

SJEKK=0
[ "${1:-}" = "--sjekk" ] && SJEKK=1

JD="$(tr -d '[:space:]' < .ygg-jd 2>/dev/null || true)"
case "$JD" in
  ''|'<JD>') echo "!! .ygg-jd mangler eller er plassholder («$JD») — sett JD-nummeret først" >&2; exit 2 ;;
esac

# Hovedtreets navn, også fra en worktree (der er basename «v10b-<gren>»).
PROD="$(basename "$(dirname "$(cd "$(git rev-parse --git-common-dir)" && pwd)")")"
JDDIR="$(find "$HOME/basic" -mindepth 3 -maxdepth 3 -type d -name "${JD}_*" | head -1)"
[ -n "$JDDIR" ] || { echo "!! fant ingen mappe ${JD}_* i ~/basic" >&2; exit 2; }
JDREL="~${JDDIR#"$HOME"}"
IMPORT="@$JDREL/AGENTS.md"

mangler=()
grep -qxF "$IMPORT" CLAUDE.md || mangler+=("import i CLAUDE.md")
jq -e --arg d "$JDREL" '.permissions.additionalDirectories // [] | index($d)' \
  .claude/settings.json >/dev/null || mangler+=("additionalDirectories")
jq -e '.hooks.SessionStart // [] | map(.hooks[].command) | any(test("jd-paaminnelse"))' \
  "$JDDIR/.claude/settings.json" >/dev/null 2>&1 || mangler+=("påminnelse i JD-mappa")

if [ ${#mangler[@]} -eq 0 ]; then
  echo "koblet: $PROD ↔ $JDREL"
  exit 0
fi
if [ $SJEKK -eq 1 ]; then
  echo "ikke koblet: $PROD ↔ $JDREL — mangler: ${mangler[*]}" >&2
  exit 1
fi

if ! grep -qxF "$IMPORT" CLAUDE.md; then
  printf '\n# JD-briefen: Nåtilstand og planer er fasit der (Scripts/jd-kobling.sh)\n%s\n' "$IMPORT" >> CLAUDE.md
fi

oppdater_json() {  # <fil> <jq-filter> [jq-args...]
  local fil="$1" filter="$2"; shift 2
  local tmp; tmp="$(mktemp)"
  jq "$@" "$filter" "$fil" > "$tmp" && mv "$tmp" "$fil"
}

oppdater_json .claude/settings.json \
  '.permissions.additionalDirectories = ((.permissions.additionalDirectories // []) + [$d] | unique)' \
  --arg d "$JDREL"

mkdir -p "$JDDIR/.claude"
[ -s "$JDDIR/.claude/settings.json" ] || echo '{}' > "$JDDIR/.claude/settings.json"
MELDING="Dette er JD-mappa til et produkt. Repoets agenter, skills og testgate lastes ikke her — bruk «p $PROD»."
# `jd-paaminnelse` i kommandoen er merket sjekken over leter etter.
KOMMANDO="echo '{\"systemMessage\":\"$MELDING\"}' # jd-paaminnelse"
oppdater_json "$JDDIR/.claude/settings.json" \
  '.hooks.SessionStart = ((.hooks.SessionStart // []) + [{matcher: "startup", hooks: [{type: "command", command: $k}]}])' \
  --arg k "$KOMMANDO"

echo "koblet: $PROD ↔ $JDREL (${mangler[*]})"
