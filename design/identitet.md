# Huginn — visuell identitet

Fastsatt 2026-10-11 i `design-direction` sammen med Erik (seks runder, åtte prøver). Retningen som
data står i `tokens.css`; denne fila er begrunnelsene. Retningen revideres bare gjennom en NY runde i
`design-direction`, ikke ad hoc.

## Retningen i én setning

**Et rolig instrument i glass: mørkt eller lyst, mykt å se på, og stille til noe har en grunn til å lyse.**
Ett tall sier hva som krever deg (punktmatrise-LCD-en), og farge betyr noe eller er borte.

## Briefen (Erik)

| | |
|---|---|
| Hvem ser den | Bare Erik. |
| Temperament | Rolig og teknisk presis. |
| Liker å være i | Apper som ser bra ut og tar detaljene på alvor. (Han ga ikke navn; smaken ble funnet gjennom reaksjon på prøver.) |
| Aldri | Apper som ser dårlige ut. Aldri generisk «AI-chat» eller Telegram. |
| Etter tre sekunder | «Her har jeg lyst til å jobbe.» |
| Referanse | En iPhone-hjemskjerm-widget (periwinkle, tung versal-grotesk, glassbrikker, tallkolonner med enhet, tab-bar). |
| Tilleggskrav fra designdokumentet | Brukes i bil og uten å røre skjermen; bærer alvorlige ting (godkjenning av lås og alarm, «dobbel feil», «køen stoppet»); mørk og lys likeverdig. |

## Reglene (håndheves av `hig-design`/`web-design` og `designer`-agenten)

1. **Farge betyr noe, ellers er den borte.** Periwinkle = *krever deg* eller *pågår*. Rød = *avvik*, og
   bare det. Grønn = *alt i orden*, og bare som liten lampe eller ordet «rent». Alt annet er dempet grått.
   (Samme regel som trådflata, 21.08 runde 4.) Dekorativ farge er forbudt, også blå på etiketter.
2. **Form skiller «krever deg» fra «pågår».** Blå *fylt flate* = du må handle (Godkjenn-knappen,
   godkjenningsbrikken). Blå *strek, kant eller tone* = noe pågår (kø-segmentet, fremdriftsstreken, valgt
   tab). Valgt tab er aldri fylt, så den ikke leses som en handling.
3. **Tallet er statusen.** Heroen er et punktmatrise-tall (5×7) med «KREVER DEG» ved siden av. En normal
   dag er et grått **0** og «ALT ROLIG»: ingen brikke for godkjenning, ingen avvik, ingenting lyser. Rolig dag
   er en egen tilstand som alltid tegnes, ikke en tom variant.
4. **Aldri farge alene.** Tilstand står alltid også som ord eller form («FEILET», «VENTER», «RENT»), så
   den leses uten fargesyn og i bilen.
5. **To skrifter, to oppgaver.** Archivo (700, versaler i heroen) for ord og tall; Martian Mono for etiketter,
   enheter, tider, penger, SHA og alt teknisk. Etiketter er sperrede versaler (0,14 em). SHA og sti vises
   alltid i små bokstaver (`huginn fe50dd4`), aldri versalisert.
6. **Radiusskalaen blandes aldri:** brikke 28 · knapp 18 · bånd 16 · chip 14 · strek helt rund. LED er rund.
7. **Glass er overflate, ikke pynt.** Halvgjennomsiktig fyll, 1 px kant, en lyskant øverst. Skygge bare i
   lys modus (der den løfter brikken fra bakgrunnen); i mørk modus gir den ingenting.
8. **Mørk og lys er likeverdige, og appen følger systemet.** Samme roller, bevisst tegnede verdier i hver
   modus (ikke invertering). I begge moduser er det punktmatrise-tallet som er signaturen.
9. **Versjonen er alltid synlig** (git-sha nederst på hver skjerm, `BuildInfo`).
10. **Hvert tall som bærer tekst har målt kontrast ≥ 4,5 mot flaten.** Det er en test
    (`ThemeTests`), ikke en intensjon. `--farge-svak` er *ikke-tekst* (slukket lampe, tomt spor) og
    testen feiler hvis den blir brukt som tekst.

## Hva som ble valgt, og hvorfor (reisen)

- **Runde 1: fire ortogonale tradisjoner** på samme «Nå»-skjerm: sveitsisk typografi (A), instrumentpanel (B),
  redaksjonell (C), industridesign (D). Erik valgte **B** (lampene) og likte **tallet i D**.
- **Runde 2: B med D-tallet**, to måter: ett stort LCD-hero (B1) eller tallet i alle fire lamper (B2).
  Erik valgte **B1**. Begge ble også vist på en rolig dag, siden halve designet er hvordan «ingenting»
  ser ut.
- **Runde 3: kontrastfarge.** Ravgult spurte Erik om å bytte. Magenta og oransje ble forkastet på måling
  (flyter sammen med dempet grått for deuteranope og med rødt). Hvit, fiolett og lime ble vist.
- **Runde 4: Eriks skjermbilde** (iPhone-widget) ble oversatt til B1: periwinkle (målt ΔE ≥ 42 mot de andre
  rollene for normalt syn/protan/deutan, 21 for tritan, og mer robust enn B1-ens cyan), tung versal-grotesk,
  glassbrikker, tallkolonner, tab-bar. Resultatet var **B3**. Én bevisst avvik fra referansen: blått er ikke
  pynt på alle etiketter (regel 1).
- **Runde 5: lys og mørk** for B1 og B3. Lys B1 beholdt en mørk LCD (en avlesning satt inn i et lyst apparat);
  lys B3 ble frostet glass med en liten løftskygge. Erik valgte **B3**, «litt mykere å se på».
- **Runde 6: myk B3.** Vekt 800→700 på overskrift og tall, etiketter 600→400, rundere brikker og knapper,
  tynnere kanter, mindre mettet aksent/rød/grønn, og LCD-prikkene gløder svakt i mørk modus. Erik valgte
  **myk B3**.

## Valgt bort

| Retning | Hvorfor ikke |
|---|---|
| A — sveitsisk typografi | Tallet som status er beholdt, men flaten er for streng og for lite «sted å være». |
| B (ravgul/hvit/lime/fiolett) som kontrastfarge | Ravgult var ikke ønsket. Lime lignet «ok»-grønt (samme fargefamilie, feil signal). Fiolett svakest for tritanope, og «AI-fargen». Hvit er rent, men tok bort karakter. |
| C — redaksjonell | «Nå» som setninger er en idé å ta vare på for talepersonen (steg 7), men flaten ble for lav i informasjonstetthet. |
| D — industridesign | Mest «generisk app». Bare punktmatrise-tallet er tatt med. |
| B1 flat/hårstrek, B2 tallet i alle lamper | B1 var Eriks andrevalg og er dokumentert i galleriet; B2 ga fire tall med lik vekt, som leses tregere enn ett. |
| Magenta, oransje | Forkastet på fargeblind-måling (se runde 3). |
| Ren invertering for lys modus | Fargene har andre kontrastbehov mot lys flate. Hver verdi er tegnet og målt. |

## Det som ikke er tegnet eller prøvd ennå

- **Bare «Nå»-skjermen er tegnet.** Tråder, Kø, Samtale og varsler/godkjenningskort har ingen identitet-prøve.
  De følger reglene over, og hver ny skjerm kjører «miniversjonen» (2–3 komposisjonsalternativer innenfor tokens).
- **Bevegelse** er tokens fra regelen i `web-design`, ikke prøvd i en live-skjerm.
- **Dynamic Type og VoiceOver** — ikke vurdert. Må inn før første Swift-skjerm leveres.
- **App-ikon og hjemskjerm-ikon** (navnet på hjemskjermen er «Basic»).
- **Samtale- og talebildet** (steg 7) og CarPlay (steg 8): egen runde.
- **Tritanope:** aksenten er ΔE 18–21 mot dempet grått, marginalt rundt grensen på 20. Form (regel 2) bærer
  forskjellen uansett.
- **Lys modus' glass** er imitert i CSS; ekte `Material` i SwiftUI vil se annerledes ut og bør sees på
  enhet.

## Filer

- `design/tokens.css` — eneste kilde.
- `apple/AppCore/Sources/AppCore/Theme.swift` — GENERERT (`bun Scripts/gen-theme.ts`; CI kjører `--sjekk`).
- `apple/Sources/ThemeFarge.swift` — SwiftUI-bro (`Color(Theme.RGBA)`, `Theme.palett(for:)`).
- `design/utforskning/` — prøvene og galleriene (runde 1–6). `proeve-b3.html` er den levende referansen:
  `#myk` er identiteten; `#lys` og `#rolig` kombinerer (`#myk,lys,rolig`). Runde 1–5 ligger der som
  proveniens.
- Eriks referansebilde ligger ikke i git (opphavsrett hos andre).
