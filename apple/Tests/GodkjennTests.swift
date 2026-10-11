import LocalAuthentication
import Testing
import SwiftUI
import AppCore
@testable import App

private struct Bestemt: Autentisering {
    var utfall: AutentiseringsUtfall
    func autentiser(begrunnelse: String) async -> AutentiseringsUtfall { utfall }
}

/// Skriveveien i app-målet: modellen kobler brikken til `SvarTjeneste`. Selve `LAContext`-dialogen kan ikke kjøres her
/// (ingen biometri i testverten); `LokalAutentisering.utfall(for:)` testes som ren avbildning.
/// Kilde som kan holdes midt i en henting og få feile, til å spille av «oppfriskningen feiler mens du velger neste kort».
private final class StyrbarKilde: NaaKilde, @unchecked Sendable {
    private let lås = NSLock()
    private var kort: [NaaKort]
    private var feiler = false
    private var holdes = false
    private var ventende: CheckedContinuation<Void, Never>?

    init(_ kort: [NaaKort]) { self.kort = kort }

    func hold() { lås.withLock { holdes = true } }
    func sett(feiler: Bool, kort: [NaaKort]? = nil) { lås.withLock { self.feiler = feiler; if let kort { self.kort = kort } } }
    var erVentende: Bool { lås.withLock { ventende != nil } }
    func slipp() {
        let c = lås.withLock { () -> CheckedContinuation<Void, Never>? in holdes = false; defer { ventende = nil }; return ventende }
        c?.resume()
    }

    func hent() async throws -> NaaSkjerm {
        if lås.withLock({ holdes }) {
            await withCheckedContinuation { c in
                let straks = lås.withLock { () -> Bool in
                    if holdes { ventende = c; return false }
                    return true
                }
                if straks { c.resume() }
            }
        }
        let (feil, k) = lås.withLock { (feiler, kort) }
        if feil { throw URLError(.notConnectedToInternet) }
        return NaaSkjerm(naa: Naa(kort: k), traader: [], nå: Date(timeIntervalSince1970: 1_760_000_000))
    }
}

@MainActor @Suite struct GodkjennRekkefølgeTests {
    private func kort(_ id: String) -> NaaKort {
        // NaaKort har ingen offentlig init: bygg det slik klienten gjør, fra serverens JSON.
        try! TraadflataKlient.dekoder().decode(NaaKort.self, from: Data(#"{"id":"\#(id)","describe":"Kort \#(id)","status":"pending"}"#.utf8))
    }

    private func vent(_ betingelse: () -> Bool) async {
        for _ in 0..<400 where !betingelse() { try? await Task.sleep(for: .milliseconds(5)) }
    }

    private func ider(_ m: NaaModell) -> [String] { m.synligSkjerm?.godkjenninger.map(\.id) ?? [] }

    /// N1: godkjenn A, velg B mens oppfriskningen pågår, og la oppfriskningen FEILE. A skal fortsatt være skjult.
    @Test func avgjortKortTapesIkkeNårNyttKortVelgesOgOppfriskningenFeiler() async throws {
        let kilde = StyrbarKilde([kort("kort-aaaa"), kort("kort-bbbb")])
        let m = NaaModell(kilde: kilde, send: { _, _ in .avgjort }, autentisering: Bestemt(utfall: .ok))
        await m.last()
        #expect(ider(m) == ["kort-aaaa", "kort-bbbb"])
        let a = try #require(m.skjerm?.godkjenninger.first { $0.id == "kort-aaaa" })
        let b = try #require(m.skjerm?.godkjenninger.first { $0.id == "kort-bbbb" })

        kilde.hold()
        m.velg(try #require(a.godkjenn))
        let flyt = Task { await m.svar?.bekreft() }
        await vent { kilde.erVentende }
        #expect(ider(m) == ["kort-bbbb"], "A er skjult så snart svaret kom, mens oppfriskningen pågår")

        m.velg(try #require(b.godkjenn))  // kvitteringen låser ikke B
        guard case .bekrefter(let f)? = m.svar?.tilstand else { Issue.record("ventet .bekrefter(B)"); return }
        #expect(f.kortId == "kort-bbbb")

        kilde.sett(feiler: true)  // nettbrudd rett etter at POST-en gikk gjennom
        kilde.slipp()
        await flyt.value
        #expect(m.feil != nil, "oppfriskningen feilet")
        #expect(ider(m) == ["kort-bbbb"], "A står ikke igjen med aktive knapper")
        #expect(m.svar?.kvittering?.forespørsel.kortId == "kort-aaaa", "kvitteringen for A er ikke tapt")
        #expect(m.svar?.avgjorte == ["kort-aaaa"])
    }

    /// N1, variant: oppfriskningen lykkes og serveren har fjernet A. Alt er konsistent.
    @Test func avgjortKortErBorteOgKonsistentNårOppfriskningenLykkes() async throws {
        let kilde = StyrbarKilde([kort("kort-aaaa"), kort("kort-bbbb")])
        let m = NaaModell(kilde: kilde, send: { _, _ in .avgjort }, autentisering: Bestemt(utfall: .ok))
        await m.last()
        let a = try #require(m.skjerm?.godkjenninger.first { $0.id == "kort-aaaa" })
        let b = try #require(m.skjerm?.godkjenninger.first { $0.id == "kort-bbbb" })
        kilde.hold()
        m.velg(try #require(a.godkjenn))
        let flyt = Task { await m.svar?.bekreft() }
        await vent { kilde.erVentende }
        m.velg(try #require(b.godkjenn))
        kilde.sett(feiler: false, kort: [kort("kort-bbbb")])
        kilde.slipp()
        await flyt.value
        #expect(m.feil == nil)
        #expect(m.skjerm?.godkjenninger.map(\.id) == ["kort-bbbb"], "serverens liste")
        #expect(ider(m) == ["kort-bbbb"])
        #expect(m.svar?.kvittering?.forespørsel.kortId == "kort-aaaa")
    }

    /// 409 («allerede avgjort») skjuler kortet likt, også når oppfriskningen feiler.
    @Test func alleredeAvgjort409SkjulerKortetLikt() async throws {
        let kilde = StyrbarKilde([kort("kort-aaaa"), kort("kort-bbbb")])
        let m = NaaModell(
            kilde: kilde, send: { _, _ in .alleredeAvgjort("kortet er allerede avslått") }, autentisering: Bestemt(utfall: .ok)
        )
        await m.last()
        let a = try #require(m.skjerm?.godkjenninger.first { $0.id == "kort-aaaa" })
        kilde.sett(feiler: true)
        m.velg(a.avslaa)
        await m.svar?.bekreft()
        #expect(ider(m) == ["kort-bbbb"])
        #expect(m.svar?.tilstand == .feil(.alleredeAvgjort("kortet er allerede avslått")))
        #expect(m.svar?.kvittering == nil)
    }
}

@MainActor @Suite struct GodkjennModellTests {
    private func modell(_ demo: DemoAvgjort = DemoAvgjort(), aut: AutentiseringsUtfall = .ok) -> NaaModell {
        let t = KildeValg.demo(rolig: false).lagTilgang(demo: demo)
        return NaaModell(kilde: t.kilde, send: t.send, autentisering: Bestemt(utfall: aut))
    }

    private func forespørselFor(_ g: NaaSkjerm.Godkjenning) throws -> Svar.Forespørsel {
        let h = try #require(g.godkjenn)
        return try #require(g.forespørsel(for: h))
    }

    @Test func utenSkrivevei_ingenTjeneste() async {
        let m = NaaModell(kilde: DemoKilde(variant: .avvik))
        #expect(m.svar == nil)
    }

    @Test func trykkPåGodkjennÅpnerBekreftelseOgSenderIkke() async throws {
        let demo = DemoAvgjort()
        let m = modell(demo)
        await m.last()
        let g = try #require(m.skjerm?.godkjenninger.first)
        m.velg(try #require(g.godkjenn))
        guard case .bekrefter(let f)? = m.svar?.tilstand else { Issue.record("ventet .bekrefter"); return }
        #expect(f.kortId == "demo-alarm" && f.valg.key == "approve")
        #expect(f.tekst == g.tittel, "hele teksten følger med til bekreftelsen")
        #expect(!demo.erAvgjort("demo-alarm"))
    }

    @Test func godkjennEtterBekreftelseOgAutentiseringFjernerKortet() async throws {
        let m = modell()
        await m.last()
        let g = try #require(m.skjerm?.godkjenninger.first)
        m.velg(try #require(g.godkjenn))
        await m.svar?.bekreft()
        await m.last()
        #expect(m.skjerm?.godkjenninger.isEmpty == true)
        #expect(m.synligSkjerm?.godkjenninger.isEmpty == true)
    }

    @Test func avslåaFjernerKortetUtenAutentisering() async throws {
        let m = modell(aut: .feilet)
        await m.last()
        let g = try #require(m.skjerm?.godkjenninger.first)
        m.velg(g.avslaa)
        await m.svar?.bekreft()
        await m.last()
        #expect(m.skjerm?.godkjenninger.isEmpty == true)
    }

    @Test(arguments: [AutentiseringsUtfall.avbrutt, .utilgjengelig, .feilet])
    func godkjennUtenAutentiseringLarKortetStå(utfall: AutentiseringsUtfall) async throws {
        let demo = DemoAvgjort()
        let m = modell(demo, aut: utfall)
        await m.last()
        let g = try #require(m.skjerm?.godkjenninger.first)
        m.velg(try #require(g.godkjenn))
        await m.svar?.bekreft()
        #expect(!demo.erAvgjort("demo-alarm"), "ingenting avgjort uten autentisering")
        await m.last()
        #expect(m.skjerm?.godkjenninger.count == 1)
    }

    @Test func usikkertSkjulerIkkeKortetOgKreverKvittering() async throws {
        let m = modell(DemoAvgjort(atferd: .usikkert))
        await m.last()
        let g = try #require(m.skjerm?.godkjenninger.first)
        m.velg(try #require(g.godkjenn))
        await m.svar?.bekreft()
        #expect(m.svar?.tilstand == .usikker(try forespørselFor(g)))
        #expect(m.synligSkjerm?.godkjenninger.count == 1, "kortet er ikke bekreftet borte")
        m.velg(g.avslaa)  // ignoreres til kvittert
        #expect(m.svar?.tilstand == .usikker(try forespørselFor(g)))
        await m.oppdaterEtterSvar()
        #expect(m.svar?.tilstand == .ingen)
    }

    /// R2: et kort med flere handlinger har ingen Godkjenn-vei, heller ikke når handlingen lages for hånd.
    @Test func kortMedFlereHandlingerKanIkkeGodkjennesSelvOmViForsøker() async throws {
        let demo = DemoAvgjort(handlinger: .flere)
        let m = modell(demo)
        await m.last()
        let g = try #require(m.skjerm?.godkjenninger.first)
        #expect(g.godkjenn == nil)
        for key in ["send", "draft", "approve"] {
            m.velg(NaaSkjerm.Handling(kortId: g.id, valg: .godkjenn, key: key))
            #expect(m.svar?.tilstand == .ingen)
        }
        m.velg(g.avslaa)
        guard case .bekrefter(let f)? = m.svar?.tilstand else { Issue.record("Avslå skal virke"); return }
        #expect(f.valg.erAvslag)
    }

    @Test func énEgenHandlingViserSinEtikettHeltTilBegrunnelsen() async throws {
        let m = modell(DemoAvgjort(handlinger: .en))
        await m.last()
        let g = try #require(m.skjerm?.godkjenninger.first)
        m.velg(try #require(g.godkjenn))
        guard case .bekrefter(let f)? = m.svar?.tilstand else { Issue.record("ventet .bekrefter"); return }
        #expect(f.valg.key == "send" && f.valg.label == "Godkjenn «Send»")
        #expect(f.begrunnelse.hasPrefix("Godkjenn «Send»:"))
    }

    /// E1: en utførende handling merket «Avslå» presenteres som «Godkjenn «Avslå»» og sender fortsatt `send`.
    @Test func handlingMerketAvslåSerIkkeUtForÅVæreAvslag() async throws {
        let demo = DemoAvgjort(handlinger: .merketAvslaa)
        let m = modell(demo)
        await m.last()
        let g = try #require(m.skjerm?.godkjenninger.first)
        let h = try #require(g.godkjenn)
        #expect(h.label == "Godkjenn «Avslå»" && g.avslaa.label == "Avslå")
        m.velg(h)
        guard case .bekrefter(let f)? = m.svar?.tilstand else { Issue.record("ventet .bekrefter"); return }
        #expect(f.valg.label == "Godkjenn «Avslå»" && f.valg.key == "send" && f.valg.krevAutentisering)
        #expect(f.begrunnelse.hasPrefix("Godkjenn «Avslå»:"))
    }

    @Test func ukjentKortIdVelgesAldri() async throws {
        let m = modell()
        await m.last()
        m.velg(NaaSkjerm.Handling(kortId: "finnes-ikke", valg: .godkjenn, key: "approve"))
        #expect(m.svar?.tilstand == .ingen)
    }
}

@Suite struct LokalAutentiseringTests {
    @Test func laErrorAvbildesUtenÅGiJa() {
        #expect(LokalAutentisering.utfall(for: .userCancel) == .avbrutt)
        #expect(LokalAutentisering.utfall(for: .systemCancel) == .avbrutt)
        #expect(LokalAutentisering.utfall(for: .passcodeNotSet) == .utilgjengelig)
        #expect(LokalAutentisering.utfall(for: .biometryNotAvailable) == .utilgjengelig)
        #expect(LokalAutentisering.utfall(for: .authenticationFailed) == .feilet)
        #expect(LokalAutentisering.utfall(for: nil) == .utilgjengelig)
        for k in [LAError.Code.authenticationFailed, .invalidContext, .notInteractive, .biometryLockout] {
            #expect(LokalAutentisering.utfall(for: k) != .ok, "ingen feilkode gir ok")
        }
    }

    #if DEBUG
    /// R1: auto-autentisering bare for en demo-kilde og bare med argumentet. Mot live er den alltid den ekte.
    @Test func autoAutentiseringBareForDemoKilde() {
        let demo = KildeValg.demo(rolig: false)
        let live = KildeValg.live(url: URL(string: "https://eksempel.example.com")!, token: "tok-0123456789abcdef01234567")
        #expect(velgAutentisering(argumenter: ["--auto-godkjenn"], valg: demo) is AutoAutentisering)
        #expect(!(velgAutentisering(argumenter: [], valg: demo) is AutoAutentisering))
        #expect(velgAutentisering(argumenter: ["--auto-godkjenn"], valg: live) is LokalAutentisering)
        #expect(velgAutentisering(argumenter: ["--auto-godkjenn", "--demo"], valg: live) is LokalAutentisering)
    }
    #endif
}
