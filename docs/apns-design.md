# Push-varsler (APNs) for Basic — design

Status: utkast 2026-10-17 (architect). Ikke implementert. Mål: et ventende godkjenningskort når Erik
på låseskjermen uten at appen er åpen. Pushen sier bare «noe venter», et trykk åpner kortet, og
Godkjenn krever fortsatt Face ID + bekreftelsesark.

## 1. Hva som finnes i dag

- **Kjernen sender allerede APNs** (`~/code/kjerne/src/apns.ts`): HTTP/2, ES256-JWT, **én global topic**
  (`KJERNE_APNS_TOPIC`) og **én global vert** (`KJERNE_APNS_HOST`) fra `/etc/kjerne/varsel.env`. I dag er
  topic v10b-appens, `no.v10b.App` (README, `install.sh --apns-fra-v10b`, som faller tilbake på sandbox-verten).
- **Kjernen eier nøkkelen**: `/etc/kjerne/apns/AuthKey.p8` (root:kjerne 0640), kopiert fra v10b-serveren.
  Plattformen kan ikke lese den.
- **Enhetstokens** ligger i `/etc/kjerne/apns/enheter.json` (`[{navn, token}]`) og skrives **bare av root**
  (`sudo kjerne-enhet add|remove`). Døde tokens (410) merkes i `/var/lib/kjerne/apns-doede.json`. Ingen klient
  registrerer seg selv, og det er med vilje: **APNs 200 fra hvilken som helst enhet i lista teller som «varsel
  akseptert» i høyrisiko-gaten** (`varsel.ts`). Den som kan legge til et token, kan altså ta imot det som skal
  stoppe Erik.
- **Nivåer**: `kritisk` gir `time-sensitive` + lyd, `vanlig` gir lyd, `stille` gir `passive` og prioritet 5.
  Første linje blir tittel, resten brødtekst (opptil 600 tegn), og `thread-id` er `kjerne`.
- **Dyplenke-data finnes allerede**: `POST /varsel` tar `data` (opptil 8 nøkler `[a-z_]{1,24}`, strenger opptil
  120 tegn) og legger det under `kjerne` i payloaden. `{type:"godkjenning", id}` passer **uten kjerneendring**.
- **Plattformen** (`core/varsler.ts`): `vanlig` går til kjernen (APNs) og til plattformens Telegram. Det brukes av
  arbeidskøen («venter på deg») og av kost-, backup- og trådflatevakta.
- **Gap**: Forsetis `approval.requested` går **ikke** via `varsler.varsle()`. Den går til Telegram-kortet
  (`gjallarhorn.ts:389`), trådflatas strøm (`traadflata.ts:341`) og mission-feed. Et godkjenningskort gir i dag
  **ingen** APNs, heller ikke til v10b-appen.
- **v10b** er referansen på klientsiden (`apple/Sources/App.swift`): `requestAuthorization` etter innrullering,
  `registerForRemoteNotifications` ved hver oppstart og hex-tokenet til serveren (`push_registrations`).
- **huginn** har ingen entitlements og ingen push-kode. Trådflata autentiserer per enhet med bearer-token
  (`TRAADFLATA_TOKENS`: `huginn-iphone`, `huginn-simulator`).

## 2. Hva som mangler, i rekkefølge

**Apple-siden**
- I `apple/project.yml`, mål `App`: legg til `CODE_SIGN_ENTITLEMENTS: Sources/App.entitlements` med
  `aps-environment = development` (Xcode setter `production` ved distribusjonseksport). Det tvinger også frem
  en eksplisitt profil per bundle, som er ønsket (lærdommene om wildcard-profilen). `UIBackgroundModes` trengs ikke
  for synlige varsler.
- Bør tas i samme runde: `com.apple.developer.usernotifications.time-sensitive = true`. Uten den bryter kjernens
  `kritisk` ikke gjennom Fokus i Basic.
- I developer.apple.com: App ID `no.huginn.App` må ha Push Notifications slått på. Device-bygget
  (`mac-test.sh device`: `-allowProvisioningUpdates` + ASC-nøkkel `NJHCL5LW99`) skal slå på kapabiliteten og lage
  ny profil når entitlementen dukker opp. Det er forventet, men ikke verifisert. Reserve: ASC API
  `POST /v1/bundleIdCapabilities` (`PUSH_NOTIFICATIONS`). Kjøres under `wt_lock devrig-signing`.
- **Ny APNs-nøkkel trengs ikke** hvis kjernens `.p8` er team-scoped i 7W88EES2X8, fordi en slik nøkkel virker for
  alle bundles i teamet. APNs-nøkler kan ikke lages via ASC API. Trengs en ny, må Erik lage den i portalen.

**Appen** (ios-dev)
- `@UIApplicationDelegateAdaptor` (token og feil) og `UNUserNotificationCenterDelegate` (trykk og visning i forgrunnen).
- Be om tillatelse (`.alert, .sound`) **etter** Kobling, ikke ved første oppstart. Hopp over i UI-tester, fordi
  dialogen ødelegger skjermbildene i synsløkka (lærdom fra v10b).
- Kall `registerForRemoteNotifications` ved hver oppstart og send hex-token + miljø (`sandbox|produksjon`, satt per
  byggkonfigurasjon) til trådflata.
- Trykk: les `userInfo["kjerne"]`. Er `type == "godkjenning"`, åpne kortet i Nå og hent det fra trådflata. Id-en er
  utrygg inndata, så en ukjent eller avgjort id viser «allerede avgjort». Kortet ryddes med
  `removeDeliveredNotifications` når det er avgjort.
- **Ingen `UNNotificationCategory` med handlinger.** Varselet kan ikke godkjenne noe.
- Innstillinger viser token-fingeravtrykket i samme format som `kjerne-enhet list` (`abcdef…1234`).
- Ren logikk ligger i AppCore: `PushRute.parse(userInfo)`, tokenformatet og kallet i `TraadflataKlient`.

**Trådflata og plattformen** (backend-dev, yggdrasil)
- `POST /api/push/token {token, miljo}` lagrer en **kandidat** per bearer-enhet (navn, token, miljø, sist sett) i
  plattformens lager. Kandidaten gir ingen mottakerrett.
  Hvem eier hva: kjernen eier mottakerlista fordi den er en tillitsgrense. Plattformen eier bare kandidaten, som
  oppdager rotasjon og sparer Erik for å kopiere 64 hex-tegn for hånd. Ikke huginn-serveren: appens eneste kilde
  er trådflata.
- Ny abonnent på `approval.requested` sender `varsler.varsle({nivaa:"vanlig", tekst:"Basic\nEn godkjenning venter",
  data:{type:"godkjenning", id}})` **uten** plattformens Telegram, fordi gjallarhorn allerede sender kortet med
  knapper. Det krever en ny opsjon `telegram:false` i `Varsel`/`rute()`. Legg på debounce (f.eks. én push per 2 min,
  «N godkjenninger venter»), så en Forseti-byge ikke bruker opp kjernens tak på 40 per time.

**Kjernen** (bare hvis Erik velger det, se 6.1)
- `topic` og `miljo` per enhet i `enheter.json` (`kjerne-enhet add <token> <navn> --topic no.huginn.App --miljo sandbox`).
  `post()` bruker enhetens topic og vert, og standard er dagens globale verdier. Omtrent 40 linjer + tester mot falsk
  h2c-APNs (`KJERNE_APNS_URL`). Da kan v10b og Basic, og dev- og TestFlight-bygg, leve side om side.
- Alternativet uten kode er å bytte global topic med `install.sh --apns-topic no.huginn.App`. Da mister v10b-appen
  kjernens varsler, og kritisk-kanalen hviler på en app som er i aktiv utvikling.

## 3. Sikkerhet og tillitsgrenser

- **Dette blir i kjernen**: `.p8`-nøkkelen, mottakerlista, sendingen, nivåtolkningen og taket. Ingen APNs-nøkkel
  skal ligge i plattformen eller huginn-serveren. Da kunne en agent sende troverdige «kritiske» pusher til Eriks telefon.
- **Kjerneendringer** gjør Erik i en interaktiv økt. Han ser over `git diff` som erik og installerer med
  `sudo ./install.sh` (README: «Dette repoet er ikke i køens fullmakt»). Aldri via arbeidskøen, og Fable etter
  modellpolicyen. Kjernen har ingen egen AGENTS.md, så README er regelverket.
- **Mottakere legges til av Erik med passord**, etter at han har sammenlignet fingeravtrykket i appen med
  `kjerne-enhet list`. Kandidaten i trådflata kan være byttet ut av en fiendtlig prosess som kjører som erik.
- **Legg aldri simulatorens token i `enheter.json`**: en 200 til simulatoren på draupnir ville telle som «Erik er
  varslet» i høyrisiko-gaten.
- **Pushen bærer ikke innhold**: teksten er fast, og `data` er bare `{type,id}`. Teksten går via Apple og vises på
  låst skjerm.
- **Et trykk godkjenner aldri**: det åpner bare kortet. Godkjenn går fortsatt gjennom Face ID og bekreftelsesark
  (`LokalAutentisering`, `BekreftelseArk`), og trådflata krever fortsatt bearer-token på `/api/godkjenning/<id>`.

## 4. Test og verifikasjon

| Hva | Hvor | Trengs ekte enhet? |
|---|---|---|
| `PushRute`, tokenformat, klientkall (StubURLProtocol) | `swift test` på ygg | nei |
| `approval.requested` gir ett varsel med fast tekst, uten korttekst, uten Telegram-duplikat, med debounce | `bun test` (yggdrasil) | nei |
| Topic og vert per enhet mot falsk h2c-APNs (bare hvis kjerneendringen velges) | kjernens tester | nei |
| Visning og trykk-ruting | `xcrun simctl push <sim> no.huginn.App x.apns` på draupnir, XCUITest | nei (lokal injeksjon, ikke APNs) |
| Ekte APNs-levering | iPhone, dev-bygg installert med devicectl | ja |

- **Sandbox eller produksjon**: et dev-bygg fra devicectl har `aps-environment=development`. Det gir et
  sandbox-token, som må sendes til `api.sandbox.push.apple.com`. Feil vert gir `400 BadDeviceToken`, og kjernen
  merker det med vilje ikke som dødt. TestFlight og App Store bruker produksjon.
- Ekte sandbox-push til simulatoren finnes (Apple silicon, iOS 16+), men krever signert app med entitlement, og vår
  simulator-signering er ad hoc. Ikke verifisert, så regn `simctl push` som simulatorveien.
- **E2E**: installer → gi tillatelse → kandidaten dukker opp i trådflata → `sudo kjerne-enhet add …` → sammenlign
  fingeravtrykk → `sudo kjerne-enhet test` → lag en godkjenning med `scripts/einherjar-smoke.ts` → banner
  «Basic / En godkjenning venter» på låst skjerm → trykk → kortet åpnes og ingenting er avgjort → Godkjenn ber om Face ID.

## 5. Trinn

| # | Hva | Hvem | Størrelse |
|---|---|---|---|
| 0 | Les `/etc/kjerne/varsel.env` (topic, vert, team-id). Sjekk i portalen at APNs-nøkkelen er team-scoped i 7W88EES2X8 | Erik | 10 min |
| 1 | Avgjør 6.1–6.4 | Erik | — |
| 2 | Entitlements, AppDelegate, tillatelse, token til trådflata, ruting, AppCore-tester, device-bygg som fornyer profilen | ios-dev | M (~1 dag) |
| 3 | `/api/push/token`, godkjenningsvarsel med debounce, `telegram:false`. Plattformdeploy via ✅ på kjerne-boten | backend-dev | S–M (½ dag) |
| 4 | Topic og miljø per enhet, eller global topic-bytte | Erik interaktivt (arkitekt/Fable bistår), `sudo install.sh` = ✅ | S (2–3 t) |
| 5 | `sudo kjerne-enhet add`, fingeravtrykk, `test` | Erik | 5 min |
| 6 | E2E med telefonen | ios-dev + Erik | S |

Trinn 2 og 3 kan gå parallelt fordi de ligger i hvert sitt repo. Trinn 4 må være installert før trinn 5.

## Beslutninger (Erik, 2026-10-17)

1. **Topic per enhet** i kjernen (ikke global bytte): v10b og Basic lever side om side. Krever kjerneendring (trinn 4).
2. **Generisk tekst, alltid** for Basic-pushen: «Basic / En godkjenning venter» + `{type, id}`. Aldri korttekst.
3. **Nivå `vanlig`** for godkjenninger, med time-sensitive-entitlementen i appen nå. Ingen søknad om Critical Alerts.
4. **Telegram-kortet beholdes** til push er bevist over flere dager; Erik slår det av selv.
5. Tokenrotasjon (spørsmål 3 under): ikke avgjort; start med manuell `sudo kjerne-enhet add`.

## 6. Åpne spørsmål for Erik

1. **Topic**: topic per enhet i kjernen (anbefalt) eller global bytte til `no.huginn.App`?
2. **Generisk tekst overalt?** I dag går innhold til låseskjermen: arbeidskøens «venter på deg» tar med spørsmålet,
   og kjernens `kritisk` skriver «Nektet: <tekst> fra <kaller>». Dette designet gjør bare godkjenningene generiske.
3. **Tokenrotasjon**: manuell `sudo kjerne-enhet add` (anbefalt nå), eller en «ventende enhet» i kjernen som Erik
   bekrefter med ✅ på kjerne-boten (med fingeravtrykk)?
4. **Nivå for godkjenninger**: `vanlig` (anbefalt) eller time-sensitive? Time-sensitive-entitlementen nå, og søknad om
   Critical Alerts senere?
5. **Telegram**: når slås Telegram-kortet for godkjenninger av (§7)?

## Ikke verifisert

- Verdiene i `/etc/kjerne/varsel.env` og om `enheter.json` har innslag (root:kjerne, ikke lesbare for meg).
- At kjernens `.p8` er team-scoped og hører til 7W88EES2X8. huginn bygger med 7W88EES2X8, men v10bs team er ikke sjekket.
- At App ID `no.huginn.App` er registrert, og at automatisk signering slår på Push uten et besøk i portalen.
- Om ASC API har en kapabilitetstype for time-sensitive.
- v10b `apns.test.ts`, `auth.ts`, `index.ts` og `App.entitlements` er ikke lest i detalj. Klientmønsteret er hentet fra `App.swift` og `db.ts`.
