import Foundation
import Testing
@testable import AppCore

@Suite struct NaaSkjermTests {
    private let k = utcKalender()
    /// 20 minutter etter at godkjenningskortet i fixturen ble opprettet.
    private let nå = isoDato("2026-10-11T20:20:00.000Z")

    private func naa(_ fixtur: String) throws -> Naa {
        try TraadflataKlient.dekoder().decode(Naa.self, from: Fixtur.data(fixtur))
    }

    private func traader() throws -> [Traad] {
        try TraadflataKlient.dekoder().decode([Traad].self, from: Fixtur.data("traader.json"))
    }

    // MARK: - tilstand

    @Test func kreverErKortPlussAvvikSomVenter() throws {
        // naa.json: 2 ventende kort + 1 avvik med art «venter» + 1 tjenesteavvik som IKKE teller.
        let s = NaaSkjerm(naa: try naa("naa.json"), traader: [], nå: nå, kalender: k)
        #expect(s.tilstand == .krever(3))
        #expect(s.antallKrever == 3)
        #expect(s.heroTittel == "Krever deg")
    }

    @Test func tomtSvarGirRoligTilstand() throws {
        let s = NaaSkjerm(naa: try naa("naa-minimal.json"), traader: [], nå: nå, kalender: k)
        #expect(s.tilstand == .rolig)
        #expect(s.antallKrever == 0)
        #expect(s.heroTittel == "Alt rolig")
        #expect(s.heroUndertekst == "Ingenting venter på deg")
        #expect(s.godkjenninger.isEmpty && s.avvik.isEmpty && s.venter.isEmpty)
        #expect(s.plattformOk)
    }

    @Test func kortUtenStatusRegnesSomVentende() {
        let n = Naa(kort: [NaaKort(id: "x", status: nil)])
        #expect(NaaSkjerm(naa: n, traader: [], nå: nå, kalender: k).tilstand == .krever(1))
    }

    @Test func avgjortKortTellerIkke() {
        let n = Naa(kort: [NaaKort(id: "x", status: "approved")])
        #expect(NaaSkjerm(naa: n, traader: [], nå: nå, kalender: k).tilstand == .rolig)
    }

    @Test func avvikMedVenterTellerIHeroenMenViserSomVenterIkkeSomAvvik() throws {
        let s = NaaSkjerm(naa: try naa("naa.json"), traader: [], nå: nå, kalender: k)
        #expect(s.avvik.map(\.tittel) == ["forgejo"])
        #expect(s.venter.map(\.tittel) == ["ko-abc"])
        #expect(s.venter.first?.ord == "VENTER")
    }

    // MARK: - plattform

    @Test func plattformOkUtenTjenesteOgHjerteslagAvvik() {
        func ok(_ art: String) -> Bool {
            let n = Naa(avvik: [NaaAvvik(art: art, navn: "a", tekst: "b")])
            return NaaSkjerm(naa: n, traader: [], nå: nå, kalender: k).plattformOk
        }
        #expect(!ok("tjeneste"))
        #expect(!ok("hjerteslag"))
        #expect(ok("jobb"))
        #expect(ok("venter"))
    }

    // MARK: - godkjenning

    @Test func godkjenningFårTittelKildeOgAlder() throws {
        let s = NaaSkjerm(naa: try naa("naa.json"), traader: [], nå: nå, kalender: k)
        let g = try #require(s.godkjenninger.first)
        #expect(g.tittel == "Deploy huginn 6c84734 til ygg-v1")
        #expect(g.kilde == "mission:ko-abc")
        #expect(g.klasse == nil, "serveren oppgir ikke klasse; ingenting skal diktes opp")
        #expect(g.kildeRen == nil)
        #expect(g.opprettet == isoDato("2026-10-11T20:00:00.000Z"))
        #expect(g.godkjenn == NaaSkjerm.Handling(kortId: "a1b2c3d4e5f6", valg: .godkjenn, key: "approve"))
        #expect(g.avslaa == NaaSkjerm.Handling(kortId: "a1b2c3d4e5f6", valg: .avslaa, key: "deny"))
        #expect(s.heroUndertekst == "2 godkjenninger · 1 venter")
    }

    @Test func enGodkjenningGirTidIUndertekst() {
        let kort = NaaKort(id: "x", describe: "Armere alarmen", status: "pending", createdAt: nå.addingTimeInterval(-192))
        let s = NaaSkjerm(naa: Naa(kort: [kort]), traader: [], nå: nå, kalender: k)
        #expect(s.heroUndertekst == "Godkjenning · 3 min")
        #expect(s.godkjenninger[0].godkjenn.key == "approve", "standardnøkkel når kortet ikke lister handlinger")
    }

    @Test func kortUtenBeskrivelseBrukerNavnetOgSiderUtenNavnetEtterFallback() {
        let a = NaaSkjerm(naa: Naa(kort: [NaaKort(id: "1", name: "reminder")]), traader: [], nå: nå, kalender: k)
        #expect(a.godkjenninger[0].tittel == "reminder")
        let b = NaaSkjerm(naa: Naa(kort: [NaaKort(id: "2")]), traader: [], nå: nå, kalender: k)
        #expect(b.godkjenninger[0].tittel == "Godkjenning")
    }

    // MARK: - avvik

    @Test func avvikFårNorskTilstandsordOgKolonneMedTidligsteTid() {
        let n = Naa(avvik: [
            NaaAvvik(art: "jobb", navn: "hermod-backup", tekst: "siste kjøring 03:10", ts: isoDato("2026-10-11T03:10:00Z")),
            NaaAvvik(art: "tjeneste", navn: "forgejo", tekst: "failed", ts: isoDato("2026-10-11T09:00:00Z")),
        ])
        let s = NaaSkjerm(naa: n, traader: [], nå: nå, kalender: k)
        #expect(s.avvik[0].ord == "FEILET", "en jobb som avviker har feilet")
        #expect(s.avvik[0].undertekst == "siste kjøring 03:10")
        #expect(s.avvik[1].ord == "FEILET")
        #expect(s.avvik[1].undertekst == "tjeneste")
        #expect(s.avvik.allSatisfy { $0.tone == .feil })
        let kol = s.kolonner[0]
        #expect(kol.tittel == "Avvik" && kol.verdi == 2 && kol.tone == .feil)
        #expect(kol.tekst == "siden 03:10")
        #expect(kol.strek == nil)
    }

    @Test func ukjentAvvikstypeGirOrdetAvvik() {
        let n = Naa(avvik: [NaaAvvik(art: "noeNytt", navn: "x", tekst: "rart")])
        #expect(NaaSkjerm(naa: n, traader: [], nå: nå, kalender: k).avvik[0].ord == "AVVIK")
    }

    @Test func ingenAvvikGirDempetNullOgIngenStrek() throws {
        let kol = NaaSkjerm(naa: try naa("naa-minimal.json"), traader: [], nå: nå, kalender: k).kolonner[0]
        #expect(kol.verdi == 0 && kol.tone == .dempet && kol.tekst == "ingen" && kol.strek == nil)
    }

    // MARK: - tråder

    @Test func traaderIGangErAktivHolderEllerOpptatt() throws {
        // traader.json: én med aktiv holder + opptatt, én parkert, én arkivert (holder aktiv: false).
        let nåTråd = Date(timeIntervalSince1970: 1_760_183_456.789 + 8 * 60)
        let s = NaaSkjerm(naa: Naa(), traader: try traader(), nå: nåTråd, kalender: k)
        #expect(s.traader.map(\.tittel) == ["Bygg trådflataklient i AppCore"])
        #expect(s.traader[0].tid == "8 min")
        #expect(s.traader[0].tone == .aksent, "status working = noe pågår")
        let kol = s.kolonner[1]
        #expect(kol.tittel == "Tråder" && kol.verdi == 1)
        // 2 ikke-arkiverte tråder, ingen venter.
        #expect(kol.strek == 0)
        #expect(kol.tekst == "ingen venter")
    }

    @Test func opptattUtenHolderTellerSomIGang() {
        let t = Traad(id: "a", tittel: "Basic", sistAktiv: nå.addingTimeInterval(-120), live: TraadLive(opptatt: true))
        let s = NaaSkjerm(naa: Naa(), traader: [t], nå: nå, kalender: k)
        #expect(s.traader.count == 1)
        #expect(s.traader[0].tone == .aksent)
    }

    @Test func aktivHolderSomBareStårÅpenErDempet() {
        let t = Traad(id: "a", tittel: "cto", sistAktiv: nå.addingTimeInterval(-3600),
                      holder: TraadHolder(type: .plattform, status: "idle", aktiv: true))
        let s = NaaSkjerm(naa: Naa(), traader: [t], nå: nå, kalender: k)
        #expect(s.traader[0].tone == .dempet)
        #expect(s.traader[0].tid == "1 t")
    }

    @Test func traadSomKortetPekerPåVenterOgStreketErAndelAvAlle() {
        let hold = TraadHolder(type: .plattform, status: "idle", aktiv: true)
        let a = Traad(id: "T1", tittel: "a", sistAktiv: nå.addingTimeInterval(-60), holder: hold)
        let b = Traad(id: "T2", tittel: "b", sistAktiv: nå.addingTimeInterval(-120), holder: hold)
        let c = Traad(id: "T3", tittel: "c", sistAktiv: nå.addingTimeInterval(-9000))  // parkert, men teller blant alle
        let kort = NaaKort(id: "k", status: "pending", threadKey: "T2")
        let s = NaaSkjerm(naa: Naa(kort: [kort]), traader: [a, b, c], nå: nå, kalender: k)
        #expect(s.traader.map(\.ord) == [nil, "VENTER"])
        #expect(s.traader[1].tid == nil)
        #expect(s.traader[1].tone == .aksent)
        let kol = s.kolonner[1]
        #expect(kol.verdi == 2)
        #expect(kol.tekst == "1 venter")
        #expect(abs((kol.strek ?? -1) - 1.0 / 3.0) < 1e-9)
    }

    @Test func blokkertHarnessStatusGirVenter() {
        let t = Traad(id: "a", tittel: "x", sistAktiv: nå, holder: TraadHolder(type: .terminal, status: "blocked", aktiv: true))
        #expect(NaaSkjerm(naa: Naa(), traader: [t], nå: nå, kalender: k).traader[0].ord == "VENTER")
    }

    @Test func arkivertTraadErAldriMed() {
        let t = Traad(id: "a", tittel: "x", sistAktiv: nå, holder: TraadHolder(type: .terminal, status: "working", aktiv: true), arkivert: nå)
        let s = NaaSkjerm(naa: Naa(), traader: [t], nå: nå, kalender: k)
        #expect(s.traader.isEmpty && s.kolonner[1].verdi == 0 && s.kolonner[1].strek == 0)
    }

    @Test func traaderSorteresNyesteFørstOgKappesVedMaks() {
        let hold = TraadHolder(type: .plattform, status: "working", aktiv: true)
        let tr = (0..<8).map { Traad(id: "t\($0)", tittel: "t\($0)", sistAktiv: nå.addingTimeInterval(Double(-$0) * 60), holder: hold) }
        let s = NaaSkjerm(naa: Naa(), traader: tr.reversed(), nå: nå, kalender: k)
        #expect(s.traader.map(\.tittel) == ["t0", "t1", "t2", "t3", "t4"])
        #expect(s.skjulteTraader == 3)
        #expect(s.kolonner[1].verdi == 8, "tallet teller alle i gang, ikke bare de viste")
    }

    // MARK: - I dag og neste

    @Test func nesteErKalenderOgPåminnelserSortertBareFremtidigeMaksTo() throws {
        // nå = 2026-10-11 20:20 UTC. Fremtid: Ring banken 22:00 i dag, Tannlege 07:30 i morgen, Ferie (hele dagen) 13.
        let s = NaaSkjerm(naa: try naa("naa.json"), traader: [], nå: nå, kalender: k)
        #expect(s.neste.map(\.etikett) == ["Neste", "Så"])
        #expect(s.neste.map(\.tittel) == ["Ring banken", "Tannlege"])
        #expect(s.neste.map(\.tid) == ["I dag 22:00", "I morgen 07:30"])
    }

    @Test func historiskeHendelserErIkkeNeste() {
        let n = Naa(kalender: [NaaKalenderHendelse(tittel: "Ferdig", kalender: nil, ts: nå.addingTimeInterval(-60), heleDagen: false)])
        #expect(NaaSkjerm(naa: n, traader: [], nå: nå, kalender: k).neste.isEmpty)
    }

    @Test func heleDagsHendelseIDagErFortsattNeste() {
        let idagStart = isoDato("2026-10-11T00:00:00Z")
        let n = Naa(kalender: [NaaKalenderHendelse(tittel: "Fridag", kalender: nil, ts: idagStart, heleDagen: true)])
        let s = NaaSkjerm(naa: n, traader: [], nå: nå, kalender: k)
        #expect(s.neste.map(\.tid) == ["I dag"])
    }

    @Test func enBegivenhetGirBareNeste() {
        let n = Naa(paminnelser: [NaaPaminnelse(tekst: "x", ts: nå.addingTimeInterval(60))])
        #expect(NaaSkjerm(naa: n, traader: [], nå: nå, kalender: k).neste.map(\.etikett) == ["Neste"])
    }

    @Test func idagKolonneTellerHendelserPåDagenOgSierNesteKlokkeslett() throws {
        let kol = NaaSkjerm(naa: try naa("naa.json"), traader: [], nå: nå, kalender: k).kolonner[2]
        #expect(kol.tittel == "I dag")
        #expect(kol.verdi == 1, "bare «Ring banken» ligger på 11. oktober")
        #expect(kol.tekst == "neste 22:00")
        #expect(kol.strek == nil)
    }

    @Test func idagKolonneTomOgFerdig() {
        let tom = NaaSkjerm(naa: Naa(), traader: [], nå: nå, kalender: k).kolonner[2]
        #expect(tom.verdi == 0 && tom.tekst == "ingenting")
        let n = Naa(paminnelser: [NaaPaminnelse(tekst: "x", ts: nå.addingTimeInterval(-60))])
        let ferdig = NaaSkjerm(naa: n, traader: [], nå: nå, kalender: k).kolonner[2]
        #expect(ferdig.verdi == 1 && ferdig.tekst == "ferdig i dag")
    }

    @Test func alltidTreKolonnerIFastRekkefølge() throws {
        let s = NaaSkjerm(naa: try naa("naa-minimal.json"), traader: [], nå: nå, kalender: k)
        #expect(s.kolonner.map(\.id) == ["avvik", "traader", "idag"])
    }

    @Test func determinismeSammeInndataGirSammeSkjerm() throws {
        let a = NaaSkjerm(naa: try naa("naa.json"), traader: try traader(), nå: nå, kalender: k)
        let b = NaaSkjerm(naa: try naa("naa.json"), traader: try traader(), nå: nå, kalender: k)
        #expect(a == b)
    }
}
