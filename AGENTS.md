# huginn

Appen **Basic** (repo/produkt `huginn`) — arbeidsflaten for Yggdrasil/Basic. Monorepo
generert fra **dev-rig-template**. Fire flater: iOS/macOS (Swift/SwiftUI), web
(Next.js/React), server (bun/TypeScript), delte typer (packages/shared).
Design og plan: `~/basic/20-29_personal/21_tech/21.09_dev-rig/design-arbeidsflate-2026-10-08.md`.
Prosjektmappe (JD 21.22): `~/basic/20-29_personal/21_tech/21.22_huginn`.

- **Bundle-prefiks:** `no.huginn`. **Schemes:** `App` (iOS), `App-macOS`.
- **Remotes:** `origin` = `git@github.com:v10b-erik/huginn.git`, `platform` =
  `ssh://git@100.64.130.46:2222/ygg/huginn.git`.
- **Database:** Postgres 17 på ygg-v1 (`127.0.0.1:5433`), `huginn` og `huginn_test`.

## Økter starter i repoet: `p <produkt> [gren]`
`p` (`~/basic/00-09_global/p/`) viser et prosjektkort (JD, gren, worktrees, CI,
siste økt, Nåtilstand) og starter `claude` i repoet eller worktreen — aldri i
JD-mappa, der denne fila, agentene, skillsene og Stop-gaten ikke lastes (målt
2026-10-08: 97 % av v10b-kallene sto der). `p` godkjenner også stien i Claude
Code; uten det ignoreres prosjektets permissions og JD-importen stille.
`Scripts/jd-kobling.sh` kobler repoet til JD-briefen (import i CLAUDE.md, JD-mappa
som tilleggskatalog, påminnelse om `p` i JD-mappa); `--sjekk` leser tilstanden.

## Byggeloop-kontrakten (ygg-v1 ⇄ draupnir)
- **Ren logikk** ligger i `apple/AppCore` (pure SwiftPM): `swift test --package-path
  apple/AppCore` kjører PÅ ygg-v1 på sekunder. Dette er den raske loopen — bruk den mest.
- **UI/integrasjon** krever Mac: `Scripts/remote-test.sh ios` rsyncer treet til draupnir
  og kjører `Scripts/mac-test.sh` der (xcodegen → xcodebuild test på simulator →
  xcresulttool-summary som JSON på stdout).
- `.xcodeproj` er et byggeartefakt (gitignored) — **rediger aldri .pbxproj**; all
  prosjektdefinisjon skjer i `apple/project.yml` (XcodeGen, kilder autodiscoveres).
- Xcode-verktøy over MCP: server `xcodebuild` i `.mcp.json` (XcodeBuildMCP på draupnir
  over ssh-stdio). Merk: verktøyets stier er Mac-lokale (`~/build/<repo>`); rsync før bygg.

## Drift: deploy, helsesjekk og tilbakerulling (tillitskjernen)
På ygg-v1 deployes et produkt i drift **bare** gjennom tillitskjernens deploy-motor
(arbeidsflate §4.7): `sudo -n /opt/kjerne/bin/produkt-deploy deploy <produkt> <sha> [--vent]`
(`Scripts/deploy-server.sh` gjør det når systemenheten finnes). Motoren og erklæringen
(`~/code/kjerne/produkter/<produkt>.json`: byggsteg, enheter, helsesjekker, vakttid) er
utenfor køens fullmakt — produktrepoet kan ikke svekke sjekken som skal fange dets egne feil.
Den henter sha-en fra `platform` main (push først), bygger som `<produkt>-build` i sandkasse,
migrerer som produktbrukeren, bytter `/opt/<produkt>` → `/opt/releases/<produkt>/<sha>`,
verifiserer, holder **vakttid** (10 min syntetisk sjekk) og ruller tilbake til siste kjente
gode av seg selv. Root kjører aldri noe fra repoet. Det produktet må levere:
- **`GET /health`** på loopback som returnerer `{ "ok": true, "sha": "<GIT_SHA>" }` (malen gjør det),
  og `"db": true` etter en ekte spørring når produktet har database — sha-en er hvordan motoren vet at den nye koden faktisk kjører.
- **Migrasjoner er expand/contract.** Bare bakoverkompatible migrasjoner deployes autonomt
  (nye tabeller, nye kolonner som er nullable eller har DEFAULT, vanlige indekser, backfill).
  DROP, RENAME, ALTER COLUMN, nye constraints på eksisterende tabeller, `DO`-blokker og endring
  av en migrasjon som finnes, parkerer deployen (exit 3) til Erik godkjenner med passord.
  Gjør kontrakt-steget i en egen, senere migrasjon når ingen kode bruker det gamle.
- Exit-kodene: 0 ok · 1 feilet før bytte (uendret) · 2 forhåndssjekk rød · 3 parkert ·
  4 rullet tilbake · 5 stoppet (dobbel feil — frigis av Erik). Status: `produkt-deploy status`.
- Tilbakerulling ruller tilbake kode, ikke skjema eller fysisk tilstand.

## Flere features samtidig (git worktree)
Én feature per worktree, én økt per worktree (`p <produkt> <gren>` lager og åpner
den). `Scripts/wt.sh new <navn>` lager
treet som søsken av repoet, kopierer kaldstartfilene (`.worktreeinclude` — en
worktree får bare SPOREDE filer, og agenter feiler forvirrende på manglende
`.env`), kjører `bun install` og tildeler en egen web-port.
`Scripts/wt.sh list` viser hva som står ute; `Scripts/wt.sh rm <navn>` river
treet OG alt det eier på byggeverten. Oppryddingen er en del av kontrakten —
og siden 2026-09-25 en mekanisme: `wt.sh sweep` river alle rene trær hvis gren
er merget i main og river det de eier på draupnir, og
`Scripts/hooks/post-merge` kjører den etter hver merge inn i main (wt.sh setter
`core.hooksPath=Scripts/hooks` første gang den kjøres i en klone). Bakgrunn: 38
merga trær i hermod sto igjen på ygg-v1 fordi «etter merge: wt.sh rm» bare var en
setning.

Alt som kan kollidere nøkles på `wt_key()` (`wt-lib.sh`) = `<produkt>-<branch>`;
hovedtreet beholder produktnavnet. Nøkkelen styrer `build/<nøkkel>` (rsync-mål),
`/tmp/dd-<nøkkel>` (DerivedData) og `sim-<nøkkel>` (**egen simulator per tre** —
«første ledige iPhone» får to trær til å overskrive hverandres app-container, og
den feilen er stille). Bundle-ID-en er med vilje UENDRET; å suffikse den ville
brutt provisjonering på device-sporet.

Serialisering på byggeverten, via mkdir-låser (`flock` finnes ikke på macOS):
- `wt_lock dd-<nøkkel>` — to xcodebuild på samme DerivedData korrumperer den.
- `wt_slot bygg 2` (`DEVRIG_MAX_BUILDS`) — tak på samtidige bygg; hver bootet
  simulator koster 1–2 GB RAM.
- `wt_lock devrig-signing` — signering er globalt eksklusiv. Samtidige
  `-allowProvisioningUpdates`-bygg lager foreldreløse «Created via API»-
  sertifikater hos Apple som må revokes manuelt før neste forsøk virker.
Lås alltid dd FØR plass — motsatt rekkefølge kan vranglåse to bygg i samme tre.
`Scripts/wt-run.sh --lock X --slot N -- <kmd>` tar låsene for kommandoer som
kjøres i ETT ssh-kall (synsløkka).

Worktrees isolerer filer, ikke betydning: agent A endrer en returtype, agent B
skriver kall mot den gamle, filene merger rent og runtime brekker. Motgiften er
integrasjonsdisiplin — rebase mot main ofte, hold features til disjunkte
moduler, og la CI kjøre på det sammenslåtte treet. Databasen deles også: rører
featuren migrasjoner, gi worktreen sin egen db.

`XCODEGEN` er grunnen til at dette i det hele tatt er billig for oss: uten
`.pbxproj` finnes ikke iOS-parallellitetens verste flettekonflikt.

## Roller, gates og workflows (.claude/)
- **Agenter** (modell-tiering): `architect` (opus/xhigh, read-only design),
  `ios-dev`/`web-dev`/`backend-dev` (sonnet, implementasjon), `reviewer`
  (opus/high, read-only dom), `designer` (opus/high, dømmer skjermbilder,
  aldri kode), `test-runner` (haiku, mekanisk).
- **Modellvalg:** se «Modellpolicy» under. Rollen bestemmer modellen, ikke økta.
- **Testgate (blokkerende):** Stop-hooken kjører raske tester for berørte
  flater (AppCore/server/web) og nekter økten å avslutte ved rødt.
  iOS-simulatorrunden er utenfor gaten — den dekkes av review/CI.
- **Destruktiv-gate:** PreToolUse blokkerer rm -rf utenfor treet, force-push
  til main, DROP/TRUNCATE og keychain-/signeringsnøkkel-endringer.
- **Review før merge er konvensjon:** kjør `reviewer`-agenten (eller
  `/review-changes`-workflowen med adversarial verifisering) på diffen før
  merge; GODKJENT kreves. Ingen teknisk sperre — tg-approve dekker farlige steg.
- **Arbeidskøen** (`verdandi ko <produkt> <oppgave>`, arbeidsflate §4.4): oppgaven
  får egen worktree (`ko-<handle>`) og en arbeider på Sonnet `high`. Plattformen — ikke
  arbeideren — tar review i fersk økt, rebase mot main, CI på grenen (derfor `ko-*` i
  `ci.yml`), fast-forward av main og deploy gjennom kjernen. Det er det eneste unntaket
  fra «merge er Eriks avgjørelse». En køarbeider merger, pusher main og deployer aldri;
  den melder `ko_ferdig`, `ko_trenger_erik` eller `ko_ny_oppgave`. Tainted oppgaver
  parkeres før merge. Produktet må stå i `KO_PRODUKTER` på plattformen.
- **Nytt produkt:** `/scaffold <navn>` (kun bruker-invokerbar).
- **Designflow:** retning finnes SAMMEN med Erik i `design-direction`
  (brief → 3–5 divergerende stilprøver → reaksjonsrunder → `design/identitet.md`
  + `design/tokens.css`). Deretter håndhever `web-design` (web) og `hig-design`
  (Swift) retningen, `Scripts/web-shot.sh` er synsløkken (bygg → se bildet →
  rett), og `design-review` er audit-passet før merge — regler i kontekst
  ryker under kontekstpress, bildet lyver ikke. Kjerneprinsipp: en slop-tell
  er en USPESIFISERT default, ikke en forbudt farge.
- **Rom/Telegram:** `.ygg-jd` i repo-rot gir speiling til produktets
  Telegram-topic fra økter i repoet; ROOM_ROUTED ruter topic-meldinger til
  terminalrommet; handoff flytter økter; tg-approve gate-r verktøykall ved
  fravær (global hook). Provisjonering: se `/scaffold` steg 7.
- **CI:** `.forgejo/workflows/ci.yml` — linux-jobb på ygg (AppCore/server/web),
  macos-jobb på draupnir (paritet + iOS-simulator). Trigges av push til Forgejo.
- **Les dommen med `Scripts/ci-status.sh`** (`--vent` for å blokkere til alle
  jobbene er ferdige; exit 0 grønn / 1 rød / 2 ikke ferdig). Runner-loggen
  skriver bare «task N plukket opp», aldri utfallet — fraværet av en feilmelding
  der beviser ingenting. Trenger `~/.config/devrig/forgejo-ci-token`
  (`read:repository`); skriptet forteller hvordan det lages. Tre feller det
  omgår: `?branch=` filtrerer IKKE på serveren, utfallet står i `status` og ikke
  i `conclusion` (som er `null` også når alt er grønt), og en kort sha må slås
  opp lokalt — API-et svarer med 40 tegn. Forventede jobber leses ut av
  `ci.yml`, så en ny jobb kreves samme dag den legges til.


## Modellpolicy (2026-10-08)

Fire modeller, valgt etter hva en feil koster. Listepris per 1M tokens inn/ut.
Effort er en like viktig spak som modellen: Opus på `medium` (standarden) kan
være dårligere enn Sonnet på `high` for kode, så porter skal ha `high` eksplisitt.

| Modell | Pris | Brukes til | Hvor det er satt |
|---|---|---|---|
| **Fable 5.1** | $10/$50 | Sjelden og bevisst: arkitektur med mange ukjente, feilsøking der Opus har gått i ring, alt som rører **tillitskjernen** (megler, taint, nøkkeltjeneste), dommer i `/arch-review`. Aldri standard noe sted. | `/model fable` |
| **Opus 5.5** | $4/$20 | Dømmekraft som avgjør utfallet: porter (`reviewer`, verify i `review-changes`, `designer`) på `high`, `architect` på `xhigh`, planlegging og ferdig-vurdering i arbeidskøen, Basic og rådgiverne. | agentfiler, workflow, Einherjar-fallback |
| **Sonnet 5.5** | $2/$10 | Volumet: hovedøkta i repoet, `ios-dev`/`web-dev`/`backend-dev`, arbeidere i køen (`high` uten tilsyn, `medium` med), review-steget i `review-changes`, generiske subagenter og `Explore`. | `.claude/settings.json`, agentfiler |
| **Haiku 5.5** | $0,10/$0,50 | Mekanisk og raskt: `test-runner`, CI-logger, sammendrag av lange verktøyresultater, utkast til daglig oppsummering, talspersoner i tale (leser og svarer kort, sender vurderinger videre), Claude Codes bakgrunnsarbeid. | agentfiler, `haiku`-aliaset |
| **Ingen modell** | — | Taint, høyrisiko-policy, løpsk-brems. Ingen modell avgjør om noe er trygt. | kode |

Regler:
- **Deleger til en navngitt rolle** (`subagent_type: ios-dev` osv.), ikke
  `general-purpose`. Generiske agenter, `Explore` og `agent()` uten `model` faller
  til `CLAUDE_CODE_SUBAGENT_MODEL` (sonnet).
- **Hovedøkta står på sonnet, fordi Erik er dømmekraften når han sitter der.**
  Bytt opp med `/model opus` eller `/model fable` ved behov. I arbeidskøen er
  ingen der, så planleggeren og ferdig-vurderingen går på Opus selv om
  arbeiderne går på Sonnet.
- **Skills:** de som krever dømmekraft (`design-review`, `design-direction`)
  løfter turen til opus via `model:`. Mekaniske (`scaffold`) har sonnet.
  Retningslinje-skills (`mac-test`, `hig-design`, `web-design`) har ingen
  `model:`, fordi den ville gjelde resten av turen for agenten som laster dem.
- **Workflows setter `model`/`effort` per `agent()`-kall.**
- **Aliasene er pinnet globalt** (`~/.claude/settings.json` → `env`
  `ANTHROPIC_DEFAULT_*_MODEL`), og Einherjar leser samme pins (`708bb20`).
  Upinnet peker `sonnet` på Sonnet 4.5 på Vertex. En oppgradering er én linje.
- **Mål kostnad per fullført oppgave, ikke per token.** `Scripts/model-usage.sh
  [--dager N]` viser forbruk per rolle × modell × effort (repo + JD-mappa fra
  `.ygg-jd`). ⚠-linjer er generiske agenter på topptier.
- **Åpne målinger** (vurderes etter et par uker med data): om Haiku holder som
  talsperson på norsk, om Sonnet på `high` holder kvaliteten i køen uten tilsyn,
  og om `reviewer` kan gå ned til Sonnet (avgjøres av hvor mange funn
  Opus-verify faktisk avviser).

## Lærdommer og referanser
- **Feltlærdommene** (signering, enheter, WCSession, widget, serve/Funnel,
  testfeller) er samlet i `21.09_dev-rig/laerdommer-apple-2026-08.md` — LES DEN
  før Apple-arbeid som involverer enheter, push, widgets eller klokke.
- **Referanseimplementasjon** for auth (per-enhet-tokens, ws-billetter,
  Funnel-klassifisering/herding), sanntid (seq/epoch/SeqGuard), klokkebro
  (treveis hierarki + utboks) og widget-mønstrene: `~/code/v10b`.
- **Versjonssynlighet er obligatorisk:** BuildInfo (i malen) viser git-sha på
  alle skjermer; remote-test.sh baker den inn. Uten den vet du ikke hvilken
  kode som kjører på hvilken enhet (Watch-synk er upålitelig).

## Konvensjoner
- **Scheme-navn:** `App` (iOS), `App-macOS`. Testmål: `AppTests` (simulator),
  `AppCoreTests` (SwiftPM). Ikke opprett nye schemes uten å oppdatere dette.
- SPM-avhengigheter pinnes (eksakt versjon) i `Package.swift`/`project.yml`.
- Sett `.accessibilityIdentifier()` på interaktive SwiftUI-views — agenter driver UI
  dramatisk bedre med navngitte elementer.
- TypeScript: delte typer bor i `packages/shared` og importeres som `@shared/types`
  fra både `web/` og `server/`. Aldri dupliser API-kontrakter.
- Tester før merge: `bun test` (server), `bun run build` (web), `swift test` (AppCore),
  `Scripts/remote-test.sh ios` (UI-endringer).
- Push til BEGGE remotes: `git push origin && git push platform`.
