---
name: scaffold
description: Instansier et nytt produkt fra dev-rig-template. Bruk når Erik sier «nytt produkt», «start <navn> fra malen» e.l. Gjør hele sekvensen — navn, remotes, database, verifisering.
argument-hint: <produktnavn>
disable-model-invocation: true
model: sonnet
---

# Nytt produkt fra malen

Produktnavn: `$0` (krev et navn hvis det mangler — kebab-case for repo,
PascalCase for appmål).

1. **Kopier malen** (aldri git clone — historikken skal være fersk):
   ```bash
   rsync -a --exclude .git --exclude node_modules --exclude .build ~/code/dev-rig-template/ ~/code/$0/
   cd ~/code/$0 && git init && git branch -M main
   ```
2. **Erstatt plassholdere:** søk/erstatt `<PRODUKTNAVN>` → produktnavnet og
   bundle-prefikset `dev.yggdrasil` → produktets prefiks i hele treet
   (AGENTS.md, project.yml, Greeting.swift, app.ts, page.tsx, layout.tsx).
3. **Remotes:** opprett privat repo `v10b-erik/$0` på GitHub (Erik gjør dette i
   GUI hvis gh/token mangler) og `ygg/$0` på Forgejo (admin-CLI-mønsteret:
   generer midlertidig token, POST /api/v1/orgs/ygg/repos, slett tokenet).
   `git remote add origin` + `platform`, push til begge.
4. **Database (lokal Postgres 17 på ygg-v1, 127.0.0.1:5433):** AlloyDB ble lagt
   ned 2026-10-08 — plattformens db er nå PGDG Postgres 17 + pgvector på ygg,
   kun loopback, scram-passord. Admin er `postgres` over peer-socket:
   `sudo -u postgres psql -p 5433` → `CREATE ROLE <navn> LOGIN PASSWORD '…'`,
   `CREATE DATABASE <navn> OWNER <navn>`, og det samme for `<navn>_test`
   (egen rolle, uten CONNECT på prod-databasen). Produktets DATABASE_URL =
   `postgres://<navn>:<pw>@127.0.0.1:5433/<navn>`; legg i server/.env (gitignored)
   og i Secret Manager `<navn>-db-url`. Nattlig backup tar alle databaser
   automatisk (ygg-pg-backup.timer).
5. **Verifiser alle fire flater** før du melder ferdig:
   ```bash
   swift test --package-path apple/AppCore
   cd server && bun install && bun test
   cd web && bun run build
   ./Scripts/remote-test.sh ios
   ```
6. Oppdater AGENTS.md i det nye repoet: produktnavn, formål, scheme-navn.
7. **Rom/Telegram-kobling** (Yggdrasil; et rom = fire registreringer):
   a. JD-nummer: opprett prosjektmappe i JD-treet (f.eks. `21.NN_<produkt>`)
      og skriv JD-nummeret i repoets `.ygg-jd` (speilet leser den via git-rot).
      Mappa får `CLAUDE.md` (to-linjers `@AGENTS.md`-inngang) + `AGENTS.md` +
      tom `logg.md`. **Nåtilstand i AGENTS.md er en tilstand, ikke en logg:**
      den sier det som er sant NÅ; kronologien appendes i `logg.md`, og
      fortrengte Nåtilstand-avsnitt flyttes dit. AGENTS.md holdes godt under
      40 k tegn — over det kuttes `@`-importen i Claude Code (målt 2026-09-05,
      da 21.11 og 21.01 måtte splittes).
      Kjør så `Scripts/jd-kobling.sh` i repoet (import av JD-briefen i
      CLAUDE.md, JD-mappa som tilleggskatalog, påminnelse om `p` i JD-mappa)
      og bekreft med `Scripts/jd-kobling.sh --sjekk`. Fra nå startes økter med
      `p <produkt>`.
   b. Muninn-prosjekt: harvesten AUTO-OPPRETTER prosjektet når JD-mappa får
      filer (sjekk journalen for `scope=project:<id>`) — manuell opprettelse
      trengs sjelden. Koble repoet:
      `memory.projects.linkRepo("<projectId>", { path: "<repo-sti>", repo: "github.com/…" })`
      — NB: andreargumentet er et OBJEKT; posisjonsargumenter gir null-rad.
   c. Telegram-topic: «opprett topic for <navn>» i Telegram (én per prosjekt).
      Kun Erik kan gjøre dette (chat-kommando).
   d+e. **Gjøres ved FØRSTE rom-økt, ikke ved scaffold** (ruting til et rom uten
      levende herdr-tab feiler): start `claude` i repoet i en herdr-tab,
      `herdr tab rename <id> <Etikett>`, legg `<jd>:<Etikett>` i ROOM_ROUTED i
      /opt/yggdrasil/.env + `systemctl restart yggdrasil`, så `speil på <jd>`.
   tg-approve gjelder automatisk (global hook). NB: ROOM_ROUTED/MIRROR_ROOMS
   finnes kun i live .env — dokumentér verdiene i produktets AGENTS.md.
8. **CI**: `.forgejo/workflows/ci.yml` følger med malen og kjører automatisk på
   push til Forgejo (runnere: ygg linux + draupnir macos). Ingen registrering.
9. **Watchdog (hvis produktet har server):** kopier v10b-watchdog-mønsteret på
   draupnir (`~/.config/devrig/<navn>-watchdog.sh` + cron */5) — poller
   `/health` fra ANNEN host enn tjenesten, Telegram etter 3 strake feil.
10. **Profil-fornyelse (hvis appen installeres på enhet):** legg en rad i
   `~/basic/00-09_global/ios-renew/apps.tsv` (navn, repo-sti, bundle-id, UDID)
   etter første device-install, og seed tilstanden:
   `date +%s > ~/.local/state/ios-renew/<navn>.last-install`.
   Development-profiler varer 365 dager — cron-jobben ios-renew (søndager 05:40
   på ygg) rebuilder og reinstallerer OTA før utløp, med Telegram-varsel.

Meld tilbake med hva som er verifisert grønt og hva som eventuelt gjenstår.
