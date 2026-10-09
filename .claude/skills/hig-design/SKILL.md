---
name: hig-design
description: Apples Human Interface Guidelines destillert til konkrete instrukser for SwiftUI-arbeid. Bruk ved all UI-endring i apple/ — nye views, navigasjon, layout, farger, ikoner — og når design skal vurderes eller «gjøres penere».
paths:
  - "apple/**/*.swift"
---

# HIG-design (mot «AI slop»)

Grunnregel: **plattformkonvensjon før egen oppfinnelse.** Når du er usikker på et
mønster, slå opp i HIG (developer.apple.com/design/human-interface-guidelines)
i stedet for å improvisere. Be aldri om «penere» — pek på prinsippet som brytes.

## Navigasjon
- Standardmønstre først: `NavigationStack` (hierarki), `TabView` (sidestilte
  områder), sheets (avgrensede oppgaver). Ikke bland dem eller finn opp egne.
- Tilbake-navigasjon skal alltid være forutsigbar; aldri fang brukeren.
- Modaler er for avsluttbare oppgaver — med eksplisitt Ferdig/Avbryt.

## Layout
- Respekter safe areas; bruk systemets spacing og `.padding()` uten tall der
  det holder. Ikke pikselpirk mot én skjermstørrelse.
- Bygg med standardkomponenter (`List`, `Form`, `GroupBox`) før egne containere.
- Én primærhandling per skjerm; sekundært innhold viker.

## Typografi og Dynamic Type
- KUN tekststiler (`.font(.title)`, `.body`, `.caption` …) — aldri hardkodede
  punktstørrelser. Alt skal tåle største tilgjengelighetsstørrelse.
- Tekst skal aldri klippes ved store størrelser — test med
  `.environment(\.dynamicTypeSize, .accessibility3)` i preview.

## Farge og materialer
- Semantiske systemfarger (`.primary`, `.secondary`, `Color(.systemBackground)`)
  — de følger lys/mørk modus gratis. Egne farger kun for merkevare, definert
  i asset catalog med begge moduser.
- Bruk systemmaterialer/glass der innhold ligger over innhold; ikke legg
  glass-effekter på alt (Liquid Glass er aksent, ikke tapet).
- Aldri farge som eneste informasjonsbærer.

## Ikoner og symboler
- SF Symbols før egne ikoner; riktig vekt/skala følger teksten automatisk.
- App-ikon og symboler skal fungere i alle moduser (lys/mørk/tinted).

## Tilgjengelighet
- `.accessibilityIdentifier()` på interaktive views (rigg-krav, driver UI-test).
- `.accessibilityLabel()` på ikonknapper uten tekst.
- Berøringsmål minst 44×44 pt. VoiceOver-rekkefølge skal gi mening.

## macOS-spesifikt (App-macOS-målet)
- **Mac-målet kompilerer de samme filene under `apple/Sources` som iOS.** iOS-only
  API kompilerer grønt på iOS og velter Mac-bygget: `.toolbar(_, for: .navigationBar)`,
  `.textInputAutocapitalization`, `UIImage`, `UIApplication`. Pakk hver inn ÉN gang —
  en `View`-extension (`utenNavigasjonslinje()`) eller en typealias
  (`Plattformbilde` = `UIImage`/`NSImage`) — i stedet for `#if os(iOS)` på hvert
  kallsted; N kallsteder er N steder å glemme guarden. CI bygger Mac-målet
  (`mac-test.sh mac`), så dette fanges ved push, ikke ved neste manuelle bygg.
- Meny-linjen er ikke valgfri: kommandoer hører hjemme i menyer med snarveier.
- Støtt drag & drop, flervindu og tastaturnavigasjon der det er naturlig.
- macOS-vinduer skal tåle vilkårlig størrelse — ingen iOS-faste rammer.

## Review-sjekkliste (brukes av reviewer/`/review-changes`)
1. Web-mønstre i SwiftUI-drakt? (hamburgermenyer, egne tab-barer, hover-logikk)
2. Hardkodede størrelser/farger som bryter Dynamic Type eller mørk modus?
3. Egne komponenter der standardkomponenter finnes?
4. Manglende accessibility-identifier/-label på interaktive elementer?
5. Følger navigasjonen et gjenkjennelig HIG-mønster?
