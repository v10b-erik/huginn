---
name: web-design
description: Designdisiplin for web — motparten til hig-design. Bruk ved all UI-endring i web/ — nye sider, komponenter, styling, layout — og når design skal vurderes eller «gjøres penere».
paths:
  - "web/**"
---

# Web-design (mot AI-slop)

Grunnregel: **en tell er en uspesifisert default, ikke en forbudt farge.**
Slop oppstår når modellen slipper å velge — ikke når den velger «feil».
En lilla du faktisk valgte og kan begrunne, passerer. En Inter ingen valgte,
gjør det ikke. (Kilde: Unslop UI, 3,2M Reddit-poster analysert, aug 2026.)

## Retning FØR styling
Før du styler noe som helst: svar på fire spørsmål (Anthropics
frontend-design-rammeverk) og skriv svaret i toppen av arbeidet:
1. **Purpose** — hva skal denne flaten gjøre for brukeren?
2. **Tone** — hvilket temperament? (rolig verktøy / leken / redaksjonell / teknisk)
3. **Constraints** — hva er låst? (tokens, identitet.md, plattform)
4. **Differentiation** — hva gjør at dette IKKE ser ut som alle andres?

Finnes `design/identitet.md` i repoet, er den fasit for 2 og 4 — les den først.
«Clean and modern» er ikke en retning; det er slop-defaulten.

## Tokens er eneste kilde
- All farge, typografi og spacing kommer fra `design/tokens.css`
  (CSS-variabler; med Tailwind: `@theme`-blokken). Aldri løse hex-verdier
  eller vilkårlige piksler i komponenter.
- Semantiske roller (`--farge-flate`, `--farge-aksent`, `--tekst-dempet`),
  ikke beskrivende navn (`--lilla`). Mørk modus fra dag én.
- Spacing på skala (4/8-basert). 80 % av hvordan en flate FØLES er rytme,
  luft og siktlinjer — grid-disiplin flytter mer enn fargevalg.

## Typografi
- Fonter VELGES, aldri arves. Inter/Roboto/Arial/system-stack som ikke-valg
  er tell nr. 1. NB: modellen konvergerer mot Space Grotesk når Inter
  forbys — det er samme refleks i ny drakt. Velg bevisst, begrunn i identitet.md.
- Høykontrast-par er interessante: display + mono, serif + geometrisk sans.
- Kun skala-stier (clamp/rem-skala), tåler 200 % zoom uten klipping.

## Farge
- Én dominant + skarp aksent slår tafatt jevnfordelt palett.
- Aldri farge som eneste informasjonsbærer.

## Bevegelse (tallene er ikke smak — de er målt; kilde: Emil Kowalski)
- Knappefeedback 100–160 ms · dropdowns 150–250 ms · modaler 200–500 ms.
- Aldri `ease-in` på UI. Innebygde CSS-easings er svake — bruk f.eks.
  `cubic-bezier(0.23, 1, 0.32, 1)`.
- Respekter `prefers-reduced-motion`. Få, velplasserte bevegelser
  (én orkestrert sidelast) slår fade-up på alt.

## Slop-tells (DATERT LISTE — se holdbarhetsregelen under)
Per august 2026 leses disse umiddelbart som AI:
- Lilla→blå gradient ingen ba om · Inter overalt · pill-badge over hero ·
  tre ikonkort på rad · kort-i-kort med grå 1px-border · skygge som pynt ·
  alt fader opp på scroll · grå lavkontrast-tekst · emoji som ikoner ·
  samme border-radius på alt.
- **OG: krem-bakgrunn + serif-display + salviegrønn.** Det var forrige
  bølges anti-slop-råd — nå er det selv den mest gjenkjennelige tellen.

**Holdbarhetsregel:** denne listen ELDES. Det fellesskapet konvergerer mot
som «smakfullt» blir neste tell. Ved tvil: er dette et valg jeg kan
begrunne fra identitet.md, eller en refleks? Revider listen når
design-review begynner å godkjenne ting som ser AI-generert ut.

## Tilgjengelighet
- Kontrast AA minimum. Synlige fokus-stater (ikke `outline: none` uten
  erstatning). Berøringsmål ≥ 44 px. Semantisk HTML før ARIA.

## Synsløkken er obligatorisk
Ingen UI-endring er ferdig usett: `Scripts/web-shot.sh <url> <ut.png>`
(+ mobilbredde 390), LES bildet, sammenlign med intensjonen, rett.
Regler i kontekst ryker under kontekstpress — bildet lyver ikke.

## Review-sjekkliste (brukes av designer/design-review)
1. Er retningen erklært (4 spørsmål) og fulgt — eller er dette refleks-design?
2. Løse hex/piksler utenfor tokens?
3. Kjenner du igjen en slop-tell fra listen — eller en NY som bør inn i den?
4. Tåler den mørk modus, 200 % zoom, 390 px bredde?
5. Bevegelse innenfor tallene, med reduced-motion-vei?
6. Fokus-stater, kontrast, berøringsmål?
