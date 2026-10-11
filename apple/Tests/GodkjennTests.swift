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

    @Test func utenSkrivevei_ingenTjeneste() async {
        let m = NaaModell(kilde: DemoKilde(variant: .avvik))
        #expect(m.svar == nil)
    }

    @Test func trykkPåGodkjennÅpnerBekreftelseOgSenderIkke() async throws {
        let demo = DemoAvgjort()
        let m = modell(demo)
        await m.last()
        let g = try #require(m.skjerm?.godkjenninger.first)
        m.velg(g.godkjenn)
        guard case .bekrefter(let f)? = m.svar?.tilstand else { Issue.record("ventet .bekrefter"); return }
        #expect(f.kortId == "demo-alarm" && f.valg.key == "approve")
        #expect(f.tekst == g.tittel, "hele teksten følger med til bekreftelsen")
        #expect(!demo.erAvgjort("demo-alarm"))
    }

    @Test func godkjennEtterBekreftelseOgAutentiseringFjernerKortet() async throws {
        let m = modell()
        await m.last()
        let g = try #require(m.skjerm?.godkjenninger.first)
        m.velg(g.godkjenn)
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
        m.velg(g.godkjenn)
        await m.svar?.bekreft()
        #expect(!demo.erAvgjort("demo-alarm"), "ingenting avgjort uten autentisering")
        await m.last()
        #expect(m.skjerm?.godkjenninger.count == 1)
    }

    @Test func usikkertSkjulerIkkeKortetOgKreverKvittering() async throws {
        let m = modell(DemoAvgjort(atferd: .usikkert))
        await m.last()
        let g = try #require(m.skjerm?.godkjenninger.first)
        m.velg(g.godkjenn)
        await m.svar?.bekreft()
        #expect(m.svar?.tilstand == .usikker(try #require(g.forespørsel(for: g.godkjenn))))
        #expect(m.synligSkjerm?.godkjenninger.count == 1, "kortet er ikke bekreftet borte")
        m.velg(g.avslaa)  // ignoreres til kvittert
        #expect(m.svar?.tilstand == .usikker(try #require(g.forespørsel(for: g.godkjenn))))
        await m.oppdaterEtterSvar()
        #expect(m.svar?.tilstand == .ingen)
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
    @Test func autoAutentiseringFinnesBareIDebugOgVelgesBareMedArgument() async {
        #expect(velgAutentisering(argumenter: ["--auto-godkjenn"]) is AutoAutentisering)
        #expect(!(velgAutentisering(argumenter: []) is AutoAutentisering))
    }
    #endif
}
