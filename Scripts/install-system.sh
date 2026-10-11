#!/bin/bash
# install-system.sh — engangs systemoppsett for huginn på ygg-v1 (hermods M8.0-mønster).
# Idempotent, kjøres som root:  sudo Scripts/install-system.sh
#
# Oppretter produktbrukeren, /etc/huginn/server.env (DATABASE_URL fra server/.env første
# gang, PORT, tom GIT_SHA som deploy-motoren fyller) og systemenheten huginn-server
# (enablet, IKKE startet). Lager med vilje IKKE /opt/huginn: den stien er deploy-motorens
# symlenke til releasen, og kjernen leser «ingenting på live-stien» som «produktet har aldri
# kjørt, databasen er tom». Byggbrukeren, deploy-nøkkelen, speilet og erklæringen
# (produkter/huginn.json) eies av tillitskjernen: `sudo ./install.sh` i ~/code/kjerne etterpå,
# og første start er kjernens: sudo -n /opt/kjerne/bin/produkt-deploy deploy huginn <sha> --vent
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$(id -u)" = 0 ] || { echo "kjør som root (sudo)" >&2; exit 1; }
EH=/home/erik
PORT=3030
say() { echo "• $*"; }

getent passwd huginn >/dev/null || useradd -r -s /usr/sbin/nologin -d /var/lib/huginn -M huginn
say "bruker: $(id huginn)"

install -d -o root -g huginn -m 0750 /etc/huginn
if [ ! -f /etc/huginn/server.env ]; then
  SRC="$EH/code/huginn/server/.env"
  grep -q '^DATABASE_URL=' "$SRC" 2>/dev/null || { echo "finner ikke DATABASE_URL i $SRC" >&2; exit 1; }
  ( umask 077; { grep -E '^DATABASE_URL=' "$SRC"; printf 'PORT=%s\nGIT_SHA=\n' "$PORT"; } > /etc/huginn/server.env )
  say "server.env opprettet fra $SRC"
fi
chown root:huginn /etc/huginn/server.env; chmod 0640 /etc/huginn/server.env
say "/etc/huginn: $(ls -1 /etc/huginn | paste -sd' ')"

install -o root -g root -m 0644 Scripts/system/huginn-server.service /etc/systemd/system/huginn-server.service
systemctl daemon-reload
systemctl enable --quiet huginn-server
say "huginn-server: $(systemctl is-enabled huginn-server), ikke startet (ingen release ennå)"
say "neste: cd ~/code/kjerne && sudo ./install.sh   # byggbruker, deploy-nøkkel, speil, erklæring"
