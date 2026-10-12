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

/// Regel 10: fanenes tekst er en tekstrolle fra paletten (dempet/aksent, begge ≥ 4,5:1 i `ThemeTests`) og har
/// ingen egen opasitet. En fane som ikke finnes ennå kan ikke trykkes, men blekner ikke under kontrastkravet.
@Suite struct TabbarTests {
    @Test func ikkeValgteFanerBrukerDempetOgValgtBrukerAksentUtenOpasitet() {
        for p in [Theme.mork, Theme.lys] {
            #expect(Tabbar.tekstfarge(valgt: false, palett: p) == p.dempet)
            #expect(Tabbar.tekstfarge(valgt: true, palett: p) == p.aksent)
            #expect(Tabbar.tekstfarge(valgt: false, palett: p) != p.svak, "svak er ikke tekstfarge")
        }
        #expect(Tabbar.opasitet == 1)
    }

    @Test func barenHarFireFanerOgBareNåErValgtOgAktiv() {
        #expect(Tabbar.faner.map(\.tittel) == ["Nå", "Tråder", "Kø", "Samtale"])
        #expect(Tabbar.faner.filter(\.valgt).map(\.id) == ["naa"])
        #expect(Tabbar.faner.filter(\.aktiv).map(\.id) == ["naa"])
    }
}

/// Heroens tittel har ÉN skriftstørrelse for alle tre tilstandene (avgjørelse 2026-10-12): skalaen hentes av det bredeste
/// ordet og tar ikke imot noe om tilstanden, så «Krever deg», «Ingen oppgaver» og «Alt rolig» kan ikke avvike fra hverandre.
@Suite struct HeroTittelTests {
    @Test func skalaGirDetBredesteOrdetPlassOgErAldriStørreEnnTokenet() {
        #expect(HeroView.skala(kolonne: 230, ord: 232) < 1)
        #expect(abs(HeroView.skala(kolonne: 200, ord: 232) * 232 - 200 * HeroView.margin) < 0.001, "ordet fyller kolonnen minus marginen")
        #expect(HeroView.skala(kolonne: 232, ord: 232) < 1, "ordet som akkurat passer får likevel luft")
        #expect(HeroView.skala(kolonne: 300, ord: 232) == 1, "god plass: tokenets størrelse")
    }

    @Test func skalaHarGulvOgTålerUkjentBredde() {
        #expect(HeroView.skala(kolonne: 10, ord: 232) == HeroView.minSkala)
        #expect(HeroView.skala(kolonne: 0, ord: 232) == 1, "før første måling")
        #expect(HeroView.skala(kolonne: 200, ord: 0) == 1)
    }

    @Test func tittelstilenErLikForAlleTilstanderOgFølgerSkalaen() {
        let full = HeroView.tittelStil(skala: 1)
        #expect(full.str == Theme.Typografi.Str.hero && full.linjehoyde == Theme.Typografi.Lh.hero)
        let liten = HeroView.tittelStil(skala: 0.9)
        #expect(abs(liten.str - Theme.Typografi.Str.hero * 0.9) < 0.0001)
        #expect(abs((liten.linjehoyde ?? 0) - Theme.Typografi.Lh.hero * 0.9) < 0.0001)
        #expect(liten.versaler && liten.familie == .visningBold)
    }
}
