import Foundation
import Testing
@testable import AppCore

@Suite struct KildeTests {
    private let k = utcKalender()
    // Søndag 15:52 UTC, som i prototypen.
    private let nå = isoDato("2026-10-11T15:52:00Z")

    @Test func demoAvvikErDagenFraPrototypen() {
        let s = DemoKilde(variant: .avvik, kalender: k).skjerm(nå: nå)
        #expect(s.topplinje == "Søndag 11. okt")
        #expect(s.tilstand == .krever(1))
        #expect(s.plattformOk)
        #expect(s.heroTittel == "Krever deg")
        #expect(s.heroUndertekst == "Godkjenning")

        let g = s.godkjenninger[0]
        #expect(g.tittel == "Armere alarmen")
        #expect(g.kilde == "kode:v10b:ajax-fix")
        #expect(g.kildeRen == true)
        #expect(g.klasse == "Høyrisiko")
        #expect(g.opprettet == nå.addingTimeInterval(-192))

        #expect(s.venter.isEmpty, "godkjenningen står også som «venter»-avvik, men er samme sak som kortet")
        #expect(s.avvik.map(\.tittel) == ["hermod-backup"])
        #expect(s.avvik[0].undertekst == "siste kjøring 03:10")
        #expect(s.kolonner[0].verdi == 1)
        #expect(s.kolonner[0].tekst == "siden 03:10")

        #expect(s.traader.map(\.tittel) == ["kode:huginn", "cto", "kode:v10b:ajax-fix"])
        #expect(s.traader.map(\.tid) == ["8 min", "1 t", nil])
        #expect(s.traader.map(\.ord) == ["PÅGÅR", nil, "VENTER"])
        #expect(s.kolonner[1].verdi == 3)
        #expect(s.kolonner[1].tekst == "1 venter")
        
        #expect(s.neste.map(\.tittel) == ["Trening", "Standup"])
        #expect(s.neste.map(\.tid) == ["I dag 18:00", "I morgen 08:30"])
    }

    @Test func demoRoligErNullOgAltRolig() {
        let s = DemoKilde(variant: .rolig, kalender: k).skjerm(nå: nå)
        #expect(s.tilstand == .rolig)
        #expect(s.heroTittel == "Alt rolig")
        #expect(s.heroUndertekst == "Ingenting venter på deg")
        #expect(s.godkjenninger.isEmpty && s.avvik.isEmpty && s.venter.isEmpty)
        #expect(s.kolonner.map(\.verdi) == [0, 3, 1])
        #expect(s.kolonner[1].tekst == "ingen venter")
        #expect(s.traader.map(\.ord) == ["PÅGÅR", nil, nil], "ingen venter, bare huginn pågår")
    }

    @Test func demoNesteErAldriHistorisk() {
        // Etter 18:00 er «Trening i dag» forbi; demoen peker da på neste forekomst, aldri bakover.
        let sent = isoDato("2026-10-11T19:30:00Z")
        let s = DemoKilde(variant: .avvik, kalender: k).skjerm(nå: sent)
        #expect(s.neste.map(\.tittel) == ["Standup", "Trening"])
        #expect(s.neste.map(\.tid) == ["I morgen 08:30", "I morgen 18:00"])
    }

    @Test func demoHentBrukerInjisertKlokke() async throws {
        let kilde = DemoKilde(variant: .rolig, nå: { isoDato("2026-10-11T08:00:00Z") }, kalender: k)
        let s = try await kilde.hent()
        #expect(s.topplinje == "Søndag 11. okt")
    }

    @Test func liveKildeByggerSkjermFraTrådflata() async throws {
        let stub = StubURLProtocol.oppsett { r in
            switch r.url?.path {
            case "/api/naa": return StubSvar(status: 200, body: try Fixtur.data("naa.json"))
            case "/api/traader": return StubSvar(status: 200, body: try Fixtur.data("traader.json"))
            default: return StubSvar(status: 404, body: Data())
            }
        }
        let klient = TraadflataKlient(baseURL: stub.baseURL, token: "tok-0123456789abcdef01234567", session: stub.session)
        let s = try await LiveKilde(klient: klient, nå: { isoDato("2026-10-11T20:20:00Z") }, kalender: k).hent()
        #expect(s.tilstand == .krever(3))
        #expect(s.plattformOk == false)  // forgejo: tjeneste feilet
        #expect(StubURLProtocol.sett(host: stub.host).count == 2)
    }

    @Test func liveKildeKasterKlientensFeil() async {
        let stub = StubURLProtocol.oppsett { _ in StubSvar(status: 401, body: Data("unauthorized".utf8)) }
        let klient = TraadflataKlient(baseURL: stub.baseURL, token: "tok-0123456789abcdef01234567", session: stub.session)
        await #expect(throws: TraadflataFeil.ikkeInnlogget) {
            try await LiveKilde(klient: klient, kalender: k).hent()
        }
    }

    @Test func klientOgLiveKildeLekkerAldriTokenet() {
        let klient = TraadflataKlient(baseURL: URL(string: "https://ygg.example")!, token: "tok-hemmelig-123")
        let live = LiveKilde(klient: klient)
        for v in [klient as Any, live as Any] {
            var dumpet = ""
            dump(v, to: &dumpet)
            for tekst in ["\(v)", String(reflecting: v), dumpet] {
                #expect(!tekst.contains("hemmelig"), "tokenet lekket i: \(tekst)")
            }
        }
        #expect(klient.description == "TraadflataKlient(ygg.example)")
    }

    @Test func kildeValgLekkerIkkeVedDump() {
        var dumpet = ""
        dump(KildeValg.live(url: URL(string: "https://x.example")!, token: "tok-hemmelig-123"), to: &dumpet)
        #expect(!dumpet.contains("hemmelig"))
    }

    @Test func feilVisesSomAvviksraderUtenInnholdEllerToken() {
        let ut = NaaFeil.fra(TraadflataFeil.ikkeInnlogget)
        #expect(ut.tittel == "Ikke innlogget")
        #expect(ut.kreverNyttToken, "401 tilbyr «Koble til på nytt», ikke «Prøv igjen»")
        for feil in [TraadflataFeil.nettverk("offline"), .http(status: 500, melding: "hemmelig"), .dekoding("tok-abc"), .ugyldigSvar] {
            let f = NaaFeil.fra(feil)
            #expect(f.tittel == "Kan ikke nå trådflata")
            #expect(!f.kreverNyttToken)
            #expect(!f.detalj.contains("hemmelig") && !f.detalj.contains("tok-abc") && !f.detalj.contains("offline"))
        }
    }
}

@Suite struct KildeValgTests {
    private let miljo = ["HUGINN_URL": "https://ygg-v1.example:3449", "HUGINN_TOKEN": "tok-hemmelig-123"]
    private let lagret = Tilkobling(baseURL: URL(string: "https://lagret.example:8444")!, token: "lagret-hemmelig-0123456789")

    @Test func ingenKildeErStandard() {
        #expect(KildeValg.velg(argumenter: [], miljo: [:], tillatLive: true) == nil)
        #expect(KildeValg.velg(argumenter: [], miljo: miljo, tillatLive: false) == nil, "release ignorerer miljøet helt")
    }

    @Test func demoVelgesMedLaunchArgument() {
        #expect(KildeValg.velg(argumenter: ["--demo"], miljo: [:], tillatLive: true) == .demo(rolig: false))
        #expect(KildeValg.velg(argumenter: ["--demo-rolig"], miljo: [:], tillatLive: true) == .demo(rolig: true))
    }

    @Test func launchArgumentSlårMiljøOgLagret() {
        #expect(KildeValg.velg(argumenter: ["--demo"], miljo: miljo, tillatLive: true, lagret: lagret) == .demo(rolig: false))
        #expect(KildeValg.velg(argumenter: ["--demo-rolig"], miljo: miljo, tillatLive: false, lagret: lagret) == .demo(rolig: true))
    }

    @Test func miljøSlårLagretIDebug() {
        #expect(KildeValg.velg(argumenter: [], miljo: miljo, tillatLive: true, lagret: lagret)
            == .live(url: URL(string: "https://ygg-v1.example:3449")!, token: "tok-hemmelig-123"))
    }

    @Test func lagretBrukesNårIngetAnnetErValgt() {
        let forventet = KildeValg.live(url: lagret.baseURL, token: lagret.token)
        #expect(KildeValg.velg(argumenter: [], miljo: [:], tillatLive: true, lagret: lagret) == forventet)
        // Release: miljøet ignoreres, men det lagrede gjelder.
        #expect(KildeValg.velg(argumenter: [], miljo: miljo, tillatLive: false, lagret: lagret) == forventet)
    }

    @Test func liveKreverBådeUrlOgTokenOgTillatelse() {
        #expect(KildeValg.velg(argumenter: [], miljo: miljo, tillatLive: true)
            == .live(url: URL(string: "https://ygg-v1.example:3449")!, token: "tok-hemmelig-123"))
        #expect(KildeValg.velg(argumenter: [], miljo: ["HUGINN_URL": "https://x.example"], tillatLive: true) == nil)
        #expect(KildeValg.velg(argumenter: [], miljo: ["HUGINN_TOKEN": "t"], tillatLive: true) == nil)
        #expect(KildeValg.velg(argumenter: [], miljo: ["HUGINN_URL": "https://x.example", "HUGINN_TOKEN": ""], tillatLive: true) == nil)
    }

    @Test func ugyldigUrlIMiljøIgnoreres() {
        #expect(KildeValg.velg(argumenter: [], miljo: ["HUGINN_URL": "ikke en url", "HUGINN_TOKEN": "t"], tillatLive: true) == nil)
        #expect(KildeValg.velg(argumenter: [], miljo: ["HUGINN_URL": "file:///etc/passwd", "HUGINN_TOKEN": "t"], tillatLive: true) == nil)
        #expect(KildeValg.velg(argumenter: [], miljo: ["HUGINN_URL": "ikke en url", "HUGINN_TOKEN": "t"], tillatLive: true, lagret: lagret)
            == lagret.kildeValg, "ugyldig miljø faller til det lagrede, ikke til demo")
    }

    @Test func tokenetLekkerAldriViaBeskrivelseEllerNavn() throws {
        let v = try #require(KildeValg.velg(argumenter: [], miljo: miljo, tillatLive: true))
        #expect(!v.description.contains("hemmelig") && !v.navn.contains("hemmelig"))
        #expect(!"\(v)".contains("hemmelig") && !String(reflecting: v).contains("hemmelig"))
        #expect(v.navn == "live · ygg-v1.example")
    }
}
