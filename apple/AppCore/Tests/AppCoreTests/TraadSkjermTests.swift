import Foundation
import Testing
@testable import AppCore

@Suite struct TraadSkjermTests {
    private let nå = isoDato("2026-10-11T15:52:00Z")
    private func min(_ m: Double) -> Date { nå.addingTimeInterval(-m * 60) }

    @Test func statusordetErAlltidSattOgFølgerHolderen() {
        let s = TraadSkjerm(traader: [
            Traad(id: "a", tittel: "A", sistAktiv: min(1), holder: TraadHolder(type: .plattform, status: "working", aktiv: true)),
            Traad(id: "b", tittel: "B", sistAktiv: min(2), holder: TraadHolder(type: .terminal, status: "blocked", aktiv: true)),
            Traad(id: "c", tittel: "C", sistAktiv: min(3), holder: TraadHolder(type: .plattform, status: "idle", aktiv: true)),
            Traad(id: "d", tittel: "D", sistAktiv: min(4)),
            Traad(id: "e", tittel: "E", sistAktiv: min(5), holder: TraadHolder(type: .plattform, status: "idle", aktiv: false)),
            Traad(id: "f", tittel: "F", sistAktiv: min(6), arkivert: min(5)),
            Traad(id: "g", tittel: "G", sistAktiv: min(7), live: TraadLive(opptatt: true)),
        ], nå: nå)
        // VENTER festes øverst; resten nyeste først.
        #expect(s.rader.map(\.ord) == ["VENTER", "PÅGÅR", "ÅPEN", "PARKERT", "PARKERT", "ARKIVERT", "PÅGÅR"])
        #expect(s.rader.map(\.tone) == [.aksent, .aksent, .dempet, .dempet, .dempet, .dempet, .aksent])
        #expect(s.rader.map(\.pågår) == [false, true, false, false, false, false, true], "bare PÅGÅR tegnes som ring")
        #expect(s.rader.allSatisfy { $0.ord != nil }, "tilstand er alltid et ord, aldri bare farge")
    }

    @Test func radeneErNyesteFørstOgViserTidenSidenSisteAktivitet() {
        let s = TraadSkjerm(traader: [
            Traad(id: "gammel", tittel: "Gammel", sistAktiv: nå.addingTimeInterval(-2 * 86_400)),
            Traad(id: "ny", tittel: "Ny", sistAktiv: min(8)),
            Traad(id: "midt", tittel: "Midt", sistAktiv: min(90)),
        ], nå: nå)
        #expect(s.rader.map(\.tittel) == ["Ny", "Midt", "Gammel"])
        #expect(s.rader.map(\.tid) == ["8 min", "1 t", "2 d"])
        #expect(s.antall == 3)
    }

    @Test func underteksterBareNårAPIetHarNoeÅSi() {
        let s = TraadSkjerm(traader: [
            Traad(id: "a", tittel: "A", sistAktiv: min(1), holder: TraadHolder(type: .terminal, status: "idle", aktiv: true),
                  prosjekt: TraadProsjekt(label: "00.00 eksempel"), ko: 2),
            Traad(id: "b", tittel: "B", sistAktiv: min(2)),
            Traad(id: "c", tittel: "C", sistAktiv: min(3), holder: TraadHolder(type: .ukjent("ny-type"), aktiv: true), ko: 0),
            Traad(id: "d", tittel: "D", sistAktiv: min(4), holder: TraadHolder(type: .plattform, aktiv: false), prosjekt: TraadProsjekt(label: "")),
        ], nå: nå)
        #expect(s.rader[0].undertekst == "00.00 eksempel")
        #expect(s.rader[0].tillegg == "2\u{00A0}i\u{00A0}kø", "«N i kø» er en egen linje og udelelig (hardt mellomrom), aldri etter en «·»")
        #expect(s.rader[0].brytFritt && s.rader[0].undertekstLinjer == 1)
        #expect(s.rader[1].undertekst == nil)
        #expect(s.rader[2].undertekst == nil)
        #expect(s.rader[2].talesTekst.contains("ny-type"))
        #expect(s.rader[3].undertekst == nil, "inaktiv holder og tom prosjektetikett gir ingenting å vise")
    }

    @Test func talesTeksten() {
        let s = TraadSkjerm(traader: [
            Traad(id: "a", tittel: "Eksempel", sistAktiv: min(8), holder: TraadHolder(type: .plattform, status: "working", aktiv: true), ko: 1),
            Traad(id: "b", tittel: "Nå-tråd", sistAktiv: nå.addingTimeInterval(-10)),
        ], nå: nå)
        #expect(s.rader[1].talesTekst == "Eksempel, pågår, plattform, 1 i kø, sist aktiv for 8 minutter siden")
        #expect(s.rader[0].talesTekst == "Nå-tråd, parkert, sist aktiv nå")
    }

    @Test func venterFestesØverstOgRestenErNyesteFørst() {
        let s = TraadSkjerm(traader: [
            Traad(id: "ny", tittel: "Ny", sistAktiv: min(1)),
            Traad(id: "v-gammel", tittel: "V gammel", sistAktiv: min(500), holder: TraadHolder(type: .terminal, status: "blocked", aktiv: true)),
            Traad(id: "midt", tittel: "Midt", sistAktiv: min(30)),
            Traad(id: "v-ny", tittel: "V ny", sistAktiv: min(20), holder: TraadHolder(type: .terminal, status: "blocked", aktiv: true)),
        ], nå: nå)
        #expect(s.venter.map(\.tittel) == ["V ny", "V gammel"])
        #expect(s.ovrige.map(\.tittel) == ["Ny", "Midt"])
        #expect(s.rader.map(\.tittel) == ["V ny", "V gammel", "Ny", "Midt"])
        #expect(s.statusTekst == "2 venter")
        #expect(s.antallTekst == "4 tråder · 30 d")
        #expect(TraadSkjerm(traader: [], nå: nå).statusTekst == "Alt rolig")
        #expect(TraadSkjerm(traader: [], nå: nå).antallTekst == "0 tråder · 30 d")
        #expect(TraadSkjerm.antallTekst(1) == "1 tråd · 30 d")
        #expect(TraadSkjerm.antallTekst(nil) == "30 d", "ukjent antall: bare vinduet")
    }

    @Test func likSistAktivAvgjøresAvIdOgErStabil() {
        let t = min(5)
        let a = [Traad(id: "a", tittel: "A", sistAktiv: t), Traad(id: "c", tittel: "C", sistAktiv: t), Traad(id: "b", tittel: "B", sistAktiv: t)]
        let ut = TraadSkjerm(traader: a, nå: nå).rader.map(\.id)
        #expect(ut == ["a", "b", "c"], "lik tid: id stigende, så rekkefølgen er stabil")
        #expect(TraadSkjerm(traader: a.reversed(), nå: nå).rader.map(\.id) == ut, "samme rekkefølge uansett inndata")
    }

    @Test func blokkertOgOpptattErVenterOgArkivertVenterAldri() {
        let s = TraadSkjerm(traader: [
            Traad(id: "a", tittel: "A", sistAktiv: min(1), holder: TraadHolder(type: .terminal, status: "blocked", aktiv: true), live: TraadLive(opptatt: true)),
            Traad(id: "b", tittel: "B", sistAktiv: min(2), holder: TraadHolder(type: .terminal, status: "blocked", aktiv: true), arkivert: min(1)),
        ], nå: nå)
        #expect(s.rader.map(\.ord) == ["VENTER", "ARKIVERT"])
        #expect(s.venter.count == 1)
        #expect(s.rader[0].pågår == false)
    }

    @Test func friskhetGjelderEtterSekstiSekunder() {
        #expect(TraadSkjerm.erGammel(sistHentet: nil, nå: nå))
        #expect(!TraadSkjerm.erGammel(sistHentet: nå.addingTimeInterval(-60), nå: nå))
        #expect(TraadSkjerm.erGammel(sistHentet: nå.addingTimeInterval(-61), nå: nå))
    }

    @Test func tomListeErEnEgenTilstandMedAvgrensningenSagt() {
        let tom = TraadSkjerm(traader: [], nå: nå)
        #expect(tom.rader.isEmpty)
        #expect(tom.tomTekst == "Ingen tråder de siste 30 dagene")
        #expect(!tom.kanVæreAvkortet)
    }

    @Test func serverensGrenseGirBeskjedOmAtListenKanVæreAvkortet() {
        let mange = (0..<TraadSkjerm.serverGrense).map { Traad(id: "t\($0)", tittel: "T\($0)", sistAktiv: min(Double($0))) }
        #expect(TraadSkjerm(traader: mange, nå: nå).kanVæreAvkortet)
        #expect(!TraadSkjerm(traader: Array(mange.dropLast()), nå: nå).kanVæreAvkortet)
    }

    @Test func serverFormenFraFixturenGirRader() throws {
        let traader = try TraadflataKlient.dekoder().decode([Traad].self, from: Fixtur.data("traader.json"))
        let s = TraadSkjerm(traader: traader, nå: Date(timeIntervalSince1970: 1_760_183_456 + 300))
        #expect(s.antall == traader.count)
        #expect(s.rader.allSatisfy { $0.ord != nil })
    }
}

@Suite struct TraadKildeTests {
    private let nå = isoDato("2026-10-11T15:52:00Z")

    @Test func demoKildenErSyntetiskOgViserAlleTilstandene() async throws {
        let s = try await DemoTraadKilde(variant: .noen, nå: { nå }).hent()
        #expect(Set(s.rader.compactMap(\.ord)).isSuperset(of: ["PÅGÅR", "VENTER", "ÅPEN", "PARKERT"]))
        #expect(s.rader.allSatisfy { $0.tittel.contains("eksempel") }, "bare syntetiske navn")
    }

    @Test func demoTomErTom() async throws {
        #expect(try await DemoTraadKilde(variant: .tom, nå: { nå }).hent().rader.isEmpty)
    }

    #if DEBUG
    @Test func demoFeilKasterOgIkkeInnloggetErEn401() async {
        await #expect(throws: TraadflataFeil.self) { try await DemoTraadKilde(variant: .feil, nå: { nå }).hent() }
        await #expect(throws: TraadflataFeil.ikkeInnlogget) { try await DemoTraadKilde(variant: .ikkeInnlogget, nå: { nå }).hent() }
    }
    #endif

    @Test func liveKildeHenterFraTraadflataOgFeilerHøytVedFeil() async throws {
        let s = StubURLProtocol.oppsett { _ in StubSvar(status: 200, body: try Fixtur.data("traader.json")) }
        let kilde = LiveTraadKilde(klient: TraadflataKlient(baseURL: s.baseURL, token: "tok-0123456789abcdef01234567", session: s.session), nå: { nå })
        let skjerm = try await kilde.hent()
        #expect(skjerm.antall > 0)
        #expect(StubURLProtocol.sett(host: s.host).first?.url?.path == "/api/traader")

        let s2 = StubURLProtocol.oppsett { _ in StubSvar(status: 401, body: Data()) }
        let nede = LiveTraadKilde(klient: TraadflataKlient(baseURL: s2.baseURL, token: "tok-0123456789abcdef01234567", session: s2.session), nå: { nå })
        await #expect(throws: TraadflataFeil.ikkeInnlogget) { try await nede.hent() }
    }

    @Test func livePrintAldriTokenet() {
        let klient = TraadflataKlient(baseURL: URL(string: "https://eksempel.test")!, token: "tok-0123456789abcdef01234567")
        let k = LiveTraadKilde(klient: klient)
        #expect(!"\(k) \(String(reflecting: k))".contains("tok-0123"))
    }

    @Test func tilgangenFørerEnTraadKildeOgDemoErDenSyntetiske() async throws {
        let t = KildeValg.demo(rolig: false).lagTilgang()
        #expect(try await t.traader.hent().antall > 0)
        #expect(KildeValg.demoTraader(argumenter: [], tillatLive: true) == .noen)
        #if DEBUG
        #expect(KildeValg.demoTraader(argumenter: ["--demo-traader=tom"], tillatLive: true) == .tom)
        #expect(KildeValg.demoTraader(argumenter: ["--demo-traader=feil"], tillatLive: true) == .feil)
        #expect(KildeValg.demoTraader(argumenter: ["--demo-traader=feil"], tillatLive: false) == .noen)
        #expect(KildeValg.demoTraader(argumenter: ["--demo-traader=tull"], tillatLive: true) == .noen)
        #endif
    }
}

@Suite struct HovedfaneTests {
    @Test func bareFanerSomFinnesErMedOgIngenErEnTrykkbarPlassholder() {
        #expect(Hovedfane.allCases.map(\.tittel) == ["Nå", "Tråder"])
        #expect(Hovedfane.allCases.map(\.identifier) == ["tabNaa", "tabTraader"])
        #expect(Hovedfane.start(argumenter: []) == .naa)
    }

    @Test func startfaneKanVelgesBareISynsløkka() {
        #if DEBUG
        #expect(Hovedfane.start(argumenter: ["--fane=traader"]) == .traader)
        #expect(Hovedfane.start(argumenter: ["--fane=ko"]) == .naa)
        #endif
    }
}

@Suite struct TidTalerTests {
    private let nå = isoDato("2026-10-11T15:52:00Z")
    @Test func relativTaltBøyerEnhetene() {
        func r(_ s: TimeInterval) -> String { Tid.relativTalt(fra: nå.addingTimeInterval(-s), til: nå) }
        #expect(r(30) == "nå")
        #expect(r(60) == "for 1 minutt siden")
        #expect(r(480) == "for 8 minutter siden")
        #expect(r(3600) == "for 1 time siden")
        #expect(r(7300) == "for 2 timer siden")
        #expect(r(86_400) == "for 1 dag siden")
        #expect(r(3 * 86_400) == "for 3 dager siden")
    }
}
