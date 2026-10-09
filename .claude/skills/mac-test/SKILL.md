---
name: mac-test
description: Bygg og test Apple-flaten riktig — velg riktig loop (lokal AppCore vs Mac-runde), kjør den, og les resultatene. Bruk ved all Swift-endring, ved «kjør iOS-testene», bygg på simulator/device, eller når xcodebuild/xcresult skal tolkes.
---

# Apple-bygg og -test (loop-kontrakten)

To looper — velg den billigste som beviser endringen:

## 1. Lokal loop (sekunder) — bruk mest
Ren logikk i `apple/AppCore` tester direkte på denne Linux-maskinen:

```bash
swift test --package-path apple/AppCore
```

Gjelder alt som ikke importerer SwiftUI/UIKit. Skriv testene her først; ikke
dra UI-loopen for logikkfeil.

## 2. Mac-runde (30 s–3 min) — for UI/integrasjon
Synker treet til draupnir og kjører der:

```bash
./Scripts/remote-test.sh core    # AppCore native på macOS (paritetssjekk)
./Scripts/remote-test.sh ios     # xcodegen → xcodebuild test på simulator → summary-JSON
./Scripts/remote-test.sh mac     # bygg App-macOS (kompileringssjekk)
./Scripts/remote-test.sh device  # signert bygg; printer .app-sti for devicectl
```

Scriptene er det garanterte gulvet. XcodeBuildMCP-verktøyene (server
`xcodebuild` i .mcp.json, kjører på draupnir) gir rikere primitiver — bruk dem
for interaktivt arbeid (boot_sim, screenshot, UI-automatisering, logger), men
husk at MCP-verktøyenes stier er Mac-lokale: repoet ligger i
`~/build/<repo-navn>` på draupnir, og `remote-test.sh` må ha synket før bygg.

## Resultatlesing
- `remote-test.sh ios` returnerer `xcresulttool`-summary som JSON på stdout:
  `result`, `passedTests`, `failedTests`, `testFailures[]`. Ved rødt: hent
  detaljer med `xcrun xcresulttool get test-results tests --path <bundle>` på
  draupnir — aldri lim rå xcodebuild-logg inn i konteksten.
- Skjermbilde ved UI-feil: `xcrun simctl io <UDID> screenshot` på draupnir,
  scp tilbake kun ved behov.

## Feller
- Simulator: første boot tar 30–90 s (`simctl bootstatus <UDID> -b` håndteres
  av scriptet). Pin UDID i ekte produkter.
- Signering angår KUN device-modus; simulator trenger ingen signering.
- `device`-modus er selvforsynt (build.keychain låses opp av scriptet) — ikke
  rør keychain-oppsettet.
- Installer på telefon: `xcrun devicectl device install app --device <UDID>
  <App.app-sti>` på draupnir; launch krever ulåst skjerm.
