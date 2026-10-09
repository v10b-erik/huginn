---
name: design-direction
description: Retningsfasen — finn produktets visuelle identitet SAMMEN med Erik, én gang per produkt. Bruk ved nytt produkt, ny stor flate uten identitet, eller når Erik vil revidere retningen. Resultatet er design/identitet.md + design/tokens.css som web-design/hig-design håndhever.
model: opus
effort: high
---

# Design-retning (samarbeidsfasen)

Dette er stedet der retningen BLIR TIL — ikke en kontrollport. Formen er
divergens → reaksjon → konvergens → nedfelling. Judge-panel-mønsteret fra
arch-review, bare visuelt: uavhengige alternativer, Erik velger og blander.

## Steg 1 — Brief-samtalen (med Erik, i dialog)
Ikke start med farger. Spør, og skriv ned svarene som utkast til identitet.md:
- Hvem SER dette? (bare Erik / familien / barn / eksterne)
- Hvilket temperament? (rolig verktøy · leken · redaksjonell · teknisk presis)
- Hvilke apper liker han å VÆRE i — og hvorfor?
- Anti-referanser: hva skal dette aldri ligne?
- Hva skal en som åpner appen føle etter tre sekunder?

## Steg 2 — Divergerende stilprøver (3–5, bevisst ULIKE)
Samme EKTE skjerm (en flate produktet faktisk trenger) i 3–5 retninger.
Divergens kommer fra positiv spesifisitet, ikke fra «lag 5 varianter»:

- **Én navngitt designtradisjon per prøve**, ortogonale: f.eks. sveitsisk
  typografi · redaksjonell/print · brutalisme · retro-terminal · organisk/myk.
- Hver prøve FORPLIKTER seg: typografipar, palett (dominant + aksent),
  spacing-skala, ett signaturgrep — og én setning om hvorfor den svarer
  på briefen.
- **Overdriv ett hakk** forbi målet — det er lettere å temme en retning
  enn å gi personlighet til grøt.
- Bygg som selvstendige HTML-filer (`design/utforskning/proeve-N.html`),
  ekte innhold fra produktet, ikke lorem ipsum.

**Kritikkrunde FØR visning:** screenshot hver prøve
(`Scripts/web-shot.sh`), LES bildene, kjør web-design-sjekklista.
Klisjeer lukes her — Eriks runder skal brukes på smaksvalg, ikke på
åpenbar slop. Prøver som ligner hverandre er bortkastet: forkast og
lag en ny fra en fjernere tradisjon.

## Steg 3 — Reaksjonsrunden (med Erik)
- Vis prøvene side om side: galleri-HTML (grid av screenshots) eller
  bildene rett til Telegram (rom/tg-approve når produktet er rom-koblet).
- Spør IKKE «hvilken er best?» — spør hva han dras mot og hva som skurrer:
  «typografien fra B, roen fra D, aldri den fargen» er gull.
- Konvergér: neste runde er 2 BLANDINGER av det han pekte på, ikke 5 nye
  retninger. Sjelden mer enn to runder.
- **Alltid en ÅPEN runde til slutt** (Eriks regel, 2026-08-23): etter
  valgene, spør i fritekst — «hva har du på hjertet som valgene ikke
  fanget? Ønsker, idéer, ting du har sett et sted?» Strukturerte opsjoner
  styrer; den åpne runden er der HANS tanker kommer inn. Aldri frys
  retningen uten den.

## Steg 4 — Nedfelling
- `design/identitet.md`: retningen med BEGRUNNELSER — tonen, referansene,
  anti-referansene, signaturgrepene, og hva som ble valgt bort og hvorfor.
- `design/tokens.css`: retningen som data (farger med roller, typografi,
  spacing, radius, easing/varigheter). Swift-flater: speil tokens i en
  generert Theme-fil i AppCore.
- Fra nå håndhever web-design/hig-design dette; designer-agenten dømmer
  mot det. Retningen revideres bare gjennom NY runde her — ikke ad hoc.

## Per flate senere (miniversjonen)
Ny skjerm i eksisterende identitet: 2–3 KOMPOSISJONS-alternativer
(hierarki, tetthet, primærhandling) innenfor tokens — screenshot, vis,
velg, bygg. Retning diskuteres ikke på nytt; den er avgjort.
