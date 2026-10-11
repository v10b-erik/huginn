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
        #expect(f.valg.key == "send" && f.valg.label == "✉️ Send")
        #expect(f.begrunnelse.hasPrefix("✉️ Send:"))
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
