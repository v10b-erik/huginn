import Testing
import SwiftUI
import AppCore
@testable import App

@Suite struct AppTests {
    @Test func coreIsReachableFromAppTarget() {
        #expect(Greeting.message(for: "iOS").contains("Hello"))
    }
}

/// Fontene er det som lett feiler stille: `Font.custom` med et navn som ikke finnes gir systemfonten uten et ord.
/// Disse testene spør CoreText om å få akkurat de PostScript-navnene tilbake.
@Suite struct FonterTests {
    @Test func allePostScriptNavnLastesFraAppbundelen() {
        let mangler = Fonter.registrer()
        #expect(mangler.isEmpty, "fonter som ikke lastes: \(mangler)")
        for navn in Fonter.Navn.alle {
            #expect(Fonter.erLastet(navn), "\(navn) er ikke lastet")
        }
    }

    @Test func enFontSomIkkeFinnesBlirIkkeRapportertSomLastet() {
        #expect(!Fonter.erLastet("FinnesIkke-Bold"))
    }

    @Test func skriftstilerBrukerTokenenesStørrelser() {
        #expect(SkriftStil.hero.str == Theme.Typografi.Str.hero)
        #expect(SkriftStil.etikett.sperring == Theme.Typografi.Sperring.etikett)
        #expect(SkriftStil.etikett.versaler && !SkriftStil.tid.versaler, "tider og sha er aldri versaler (regel 5)")
    }
}

@MainActor @Suite struct NaaModellTests {
    @Test func demoKildeGirSkjermOgIngenFeil() async {
        let modell = NaaModell(kilde: DemoKilde(variant: .avvik))
        await modell.last()
        #expect(modell.skjerm?.tilstand == .krever(1))
        #expect(modell.feil == nil)
    }

    private struct FeilKilde: NaaKilde {
        func hent() async throws -> NaaSkjerm { throw TraadflataFeil.ikkeInnlogget }
    }

    @Test func feilGirAvviksradOgBeholderForrigeSkjerm() async {
        let modell = NaaModell(kilde: FeilKilde())
        await modell.last()
        #expect(modell.skjerm == nil)
        #expect(modell.feil?.tittel == "Ikke innlogget")
    }
}
