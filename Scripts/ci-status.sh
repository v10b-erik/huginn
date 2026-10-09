#!/bin/bash
# Hva sa CI om denne commiten? Kjøres PÅ ygg-v1 fra repo-rot.
#
#   Scripts/ci-status.sh            # dommen over HEAD
#   Scripts/ci-status.sh --vent     # vent til alle jobbene er ferdige
#   Scripts/ci-status.sh <sha>      # en bestemt commit
#
# Exit: 0 = alle forventede jobber grønne · 1 = minst én rød ·
#       2 = venter fortsatt (eller en jobb har ikke dukket opp)
#
# Uten dette må man gjette. Runner-loggen skriver bare «task N plukket opp» —
# aldri utfallet — så fraværet av en feilmelding der beviser ingenting.
#
# To feller API-et har, begge omgått her:
#   1. `?branch=` FILTRERER IKKE. Serveren returnerer hele lista uansett, så
#      filtreringen må skje lokalt. Den ufiltrerte `total_count` er kontrollen:
#      får du samme tall med en tullete branch, filtrerer serveren ikke.
#   2. Utfallet står i `status` («success»/«failure»), ikke i `conclusion` —
#      den er `null` også på grønne kjøringer, og å lese den ville gjort hver
#      kjøring til «vet ikke».
#
# Forventede jobber leses ut av `.forgejo/workflows/ci.yml`, ikke hardkodet.
# Legges det til en jobb, krever skriptet den samme dag — ellers ville et nytt
# mål kunne råtne i det stille (jf. Mac-flata som sto brukket i seks dager).
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)/.."

TOKENFIL="$HOME/.config/devrig/forgejo-ci-token"
if [ ! -s "$TOKENFIL" ]; then
  cat >&2 <<EOF
!! mangler $TOKENFIL
   Lag et lesetoken (Forgejo kjører på denne verten):
     umask 077; sudo -u git /usr/local/bin/forgejo --config /etc/forgejo/app.ini \\
       admin user generate-access-token -u erik -t ci-lesetilgang \\
       --scopes read:repository --raw > $TOKENFIL
EOF
  exit 3
fi
TOKEN="$(cat "$TOKENFIL")"

# API-et utledes av `platform`-remoten, så malen kan gjenbrukes uendret.
REMOTE="$(git remote get-url platform)"
VERT="$(printf '%s' "$REMOTE" | sed -E 's#^ssh://[^@]+@([^:/]+).*#\1#')"
BANE="$(printf '%s' "$REMOTE" | sed -E 's#.*:[0-9]+/##; s#\.git$##')"
API="http://$VERT:3000/api/v1/repos/$BANE"

VENT=0
SHA=""
for a in "$@"; do
  case "$a" in
    --vent) VENT=1 ;;
    *)      SHA="$a" ;;
  esac
done
[ -n "$SHA" ] || SHA="HEAD"
# Slå opp lokalt så en kort sha, en branch eller en tag alle virker. Finnes den
# ikke i treet, brukes argumentet som prefiks — API-et svarer med 40 tegn, så en
# rå strengsammenlikning mot «d2d9659» ville aldri truffet, og skriptet ville
# meldt «ingen kjøring» om en commit som HAR kjørt. Stille feil rapport.
SHA="$(git rev-parse --verify --quiet "$SHA^{commit}" || printf '%s' "$SHA")"
KORT="${SHA:0:7}"

# Forventede jobber = toppnivånøklene under `jobs:` i arbeidsflyten.
JOBBER="$(awk '/^jobs:/{j=1;next} j && /^[^ ]/{j=0} j && /^  [A-Za-z0-9_-]+:/{gsub(/[: ]/,"");print}' \
  .forgejo/workflows/ci.yml)"
ANTALL="$(printf '%s\n' "$JOBBER" | grep -c . || true)"

hent() {
  curl -sS -H "Authorization: token $TOKEN" "$API/actions/tasks?limit=50" \
    | SHA="$SHA" JOBBER="$JOBBER" python3 -c '
import json, os, sys
d = json.load(sys.stdin)
sha = os.environ["SHA"]
vent = set(filter(None, os.environ["JOBBER"].split("\n")))
# Lokal filtrering: se kommentaren om `?branch=` øverst.
kjor = {}
for w in d.get("workflow_runs", []):
    if w.get("head_sha", "").startswith(sha) and w.get("name") not in kjor:
        kjor[w["name"]] = w
rod = kjent = 0
for navn in sorted(vent):
    w = kjor.get(navn)
    if w is None:
        print(f"  {navn:8} — ingen kjøring registrert ennå")
        continue
    s = w.get("status")
    merke = {"success": "grønn", "failure": "RØD", "cancelled": "avbrutt"}.get(s, s)
    nr, url = w.get("run_number"), w.get("url")
    print(f"  {navn:8} {merke:8} run #{nr}  {url}")
    if s in ("success", "failure", "cancelled", "skipped"):
        kjent += 1
        if s != "success":
            rod += 1
# Ukjente jobber som CI kjørte, men arbeidsflyten vår ikke nevner — skal ikke skje,
# men å tie om dem ville vært å underrapportere.
for navn in sorted(set(kjor) - vent):
    s = kjor[navn].get("status")
    print(f"  {navn:8} (ikke i ci.yml — {s})")
print(f"STATUS {len(vent)} {kjent} {rod}")
'
}

runde() {
  UT="$(hent)"
  printf '%s\n' "$UT" | grep -v '^STATUS '
  read -r _ FORVENTET KJENT ROD <<<"$(printf '%s\n' "$UT" | grep '^STATUS ')"
}

echo "CI for $KORT ($BANE):"
runde
if [ "$VENT" = 1 ]; then
  I=0
  while [ "$KJENT" -lt "$FORVENTET" ] && [ "$I" -lt 60 ]; do
    sleep 20; I=$((I + 1))
    echo "— venter ($KJENT/$FORVENTET ferdig, ${I}0s) —"
    runde
  done
fi

if [ "$KJENT" -lt "$FORVENTET" ]; then
  echo "→ ikke ferdig: $KJENT av $FORVENTET jobber har svart"; exit 2
elif [ "$ROD" -gt 0 ]; then
  echo "→ $ROD av $FORVENTET jobber er RØDE"; exit 1
fi
echo "→ alle $FORVENTET jobber grønne"
