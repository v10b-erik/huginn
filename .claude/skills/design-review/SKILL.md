---
name: design-review
description: Visuell review av UI-endringer — screenshots av berørte flater vurderes mot sjekklistene i web-design/hig-design og produktets identitet.md. Bruk etter UI-arbeid, før merge, og når Erik ber om designvurdering.
model: opus
effort: high
---

# Design-review (audit som eget pass)

Hvorfor eget pass: regler innbakt i genereringskonteksten RYKER under
kontekstpress (dokumentert i fellesskapet: lange design-skills mister
gates — derfor anbefaler selv skill-forfatterne en separat audit).
Reviewen ser på BILDER, ikke på koden som lagde dem.

## Prosedyre

1. **Screenshots av alle berørte flater:**
   - Web: `Scripts/web-shot.sh <url> /tmp/dr-<navn>.png` — desktop (1280)
     OG mobil (390). Husk mørk modus der den finnes.
   - iOS/watchOS/widget: bygg på draupnir, så
     `ssh draupnir 'xcrun simctl io <UDID> screenshot /tmp/skjerm.png'`
     og hent med scp. (XcodeBuildMCP har også screenshot-verktøy.)
2. **LES bildene** (Read-verktøyet) — vurder det du SER, ikke det koden sier.
3. **Døm mot tre kilder, i rekkefølge:**
   a. `design/identitet.md` — følger flaten den valgte retningen?
   b. Review-sjekklista i web-design (web) / hig-design (Swift).
   c. Helhet på tvers: ser flatene ut som SAMME produkt?
4. **Funnliste:** `[KRITISK|VIKTIG|MINDRE]` + prinsippet som brytes +
   konkret fiks. Aldri «gjør det penere» — pek på regelen eller
   identitetsvalget som brytes. Nye slop-tells som oppdages, meldes
   inn til web-design-listens holdbarhetsregel.
5. **Uavhengig dom ved tvil eller større flater:** spawn `designer`-agenten
   med bildestiene — den deler ikke genererings-konteksten din og ser
   det du er blitt blind for.

## Hierarki-testen (kjør ALLTID, den fanges ikke av sjekklistene)

Sjekklistene i web-design/hig-design dømmer elementer hver for seg. Den
vanligste feilen er at hvert element er riktig og HELHETEN er flat: alt
skriker like høyt, så ingenting gjør det. Erik, om Klumpi Alarm 2026-08-26:
«statusen på toppen ser ganske lik knappene, som ser ganske lik ut loggen».

Tre spørsmål per flate, besvart fra BILDET:

1. **Hvor mange beholdere deler samme form?** Tell radius + fyll + kant +
   skygge. Bruker tre ulike ROLLER samme kort, sier overflaten at de er
   likeverdige — uansett hva typografien prøver å si.
2. **Hva har mest visuell masse?** Ikke størst enkeltelement — mest AREAL.
   Fem identiske loggkort slår ett statuskort. **Gjentakelse slår
   størrelse.** Er det ikke det viktigste som veier mest, er flaten feil.
3. **Ser det trykkbare mest trykkbart ut?** Omriss uten fyll taper mot et
   fylt kort ved siden av. Aksentfargen skal peke på ÉN handling per flate;
   deles den på tre, betyr den ingenting.

Fiksen er nesten aldri «gjør det viktigste større». Den er: **gi hvert nivå
sin egen FORM, ikke bare sin egen størrelse** — et større kort blant kort er
fortsatt et kort. Bytt type objekt (bilde/helt uten kort-krom), fyll det
trykkbare, og slå sammen lister til én beholder med hårstreker.

## Terskel
- KRITISK = bryter identitet.md, utilgjengelig (kontrast/fokus/mål),
  eller en umiskjennelig slop-tell. Blokkerer merge.
- VIKTIG = brutt sjekklistepunkt med synlig effekt. Fikses før neste flate.
- MINDRE = noteres; kan samles opp.
