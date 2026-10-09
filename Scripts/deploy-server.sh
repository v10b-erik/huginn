#!/bin/bash
# Kjøres PÅ ygg-v1 fra repo-rot: deployer serveren som systemd user-service.
# Rekkefølge (designdok drift, runde 2+3): deps → migrasjoner → restart →
# /health-verifisering. Exit ≠ 0 hvis noe feiler — ødelagt deploy skal synes NÅ.
set -euo pipefail
cd "$(dirname "$0")/.."
PRODUKT=$(basename "$PWD")
UNIT="$PRODUKT-server"
SHA=$(git rev-parse --short HEAD)
# Prod (systemenhet på ygg-v1): tillitskjernens deploy-motor (AGENTS.md «Drift»). Under er dev-veien
# med user-services.
if [ -x /opt/kjerne/bin/produkt-deploy ] && systemctl is-enabled --quiet "$UNIT" 2>/dev/null; then
  git fetch -q platform main && git merge-base --is-ancestor HEAD platform/main \
    || { echo "$SHA er ikke på platform main — push først" >&2; exit 1; }
  exec sudo -n /opt/kjerne/bin/produkt-deploy deploy "$PRODUKT" "$(git rev-parse HEAD)" "$@"
fi

cd server
"$HOME/.bun/bin/bun" install --frozen-lockfile
set -a; . .env; set +a
"$HOME/.bun/bin/bun" run src/migrate.ts
sed -i "s/^GIT_SHA=.*/GIT_SHA=$SHA/" .env

systemctl --user restart "$UNIT"
for _ in $(seq 1 15); do
  sleep 2
  if curl -sf "http://127.0.0.1:${PORT:-3010}/health" >/dev/null; then
    echo "deploy OK: $UNIT @ $SHA"
    exit 0
  fi
done
echo "DEPLOY FEILET: $UNIT svarer ikke på /health etter restart" >&2
systemctl --user status "$UNIT" --no-pager | tail -5 >&2
exit 1
