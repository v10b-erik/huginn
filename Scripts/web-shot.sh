#!/bin/bash
# Synsløkken for web: screenshot av en URL med headless Chromium (Playwright).
# Agenten LESER bildet etterpå (Read-verktøyet) — bygg, se, rett, gjenta.
#
# Bruk: Scripts/web-shot.sh <url> <ut.png> [bredde] [høyde]
#   Desktop: Scripts/web-shot.sh http://127.0.0.1:3011/ /tmp/side.png
#   Mobil:   Scripts/web-shot.sh http://127.0.0.1:3011/ /tmp/side-mobil.png 390 844
#
# Førstegangsoppsett på ny vert:
#   bunx playwright install chromium
#   sudo apt-get install -y libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 \
#     libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 \
#     libpango-1.0-0 libcairo2 libasound2t64 libnss3 libnspr4
set -euo pipefail
URL="$1"; UT="$2"; B="${3:-1280}"; H="${4:-800}"
bunx playwright screenshot --viewport-size "$B,$H" --wait-for-timeout 2000 \
  --full-page "$URL" "$UT" >/dev/null
echo "$UT"
