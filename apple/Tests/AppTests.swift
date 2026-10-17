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
/// ingen egen opasitet. Barens innhold (`Hovedfane`) testes i AppCore: bare fanene som finnes er med.
@Suite struct TabbarTests {
    @Test func ikkeValgteFanerBrukerDempetOgValgtBrukerAksent() {
        for p in [Theme.mork, Theme.lys] {
            #expect(Tabbar.tekstfarge(valgt: false, palett: p) == p.dempet)
            #expect(Tabbar.tekstfarge(valgt: true, palett: p) == p.aksent)
            #expect(Tabbar.tekstfarge(valgt: false, palett: p) != p.svak, "svak er ikke tekstfarge")
        }
    }

    @Test func barenHarBareFanerSomFinnes() {
        #expect(Hovedfane.allCases.map(\.tittel) == ["Nå", "Tråder"])
    }
}

@MainActor @Suite struct TraaderModellTests {
    private struct Feiler: TraadKilde {
        func hent() async throws -> TraadSkjerm { throw TraadflataFeil.ikkeInnlogget }
    }

    @Test func lykketHentingGirSkjermOgIngenFeil() async {
        let m = TraaderModell(kilde: DemoTraadKilde(variant: .noen))
        await m.last()
        #expect(m.skjerm?.antall == 6)
        #expect(m.feil == nil)
    }

    @Test func feilGirFeilOgIngenReserveTilDemo() async {
        let m = TraaderModell(kilde: Feiler())
        await m.last()
        #expect(m.skjerm == nil, "aldri en stille reserve")
        #expect(m.feil?.kreverNyttToken == true)
    }

    @Test func feilVedOppdateringBeholderForrigeListe() async {
        struct EnGang: TraadKilde {
            let teller = HentTeller()
            func hent() async throws -> TraadSkjerm {
                if await teller.neste() == 1 { return TraadSkjerm(traader: DemoTraadKilde.traaderForTest, nå: Date()) }
                throw TraadflataFeil.nettverk("nede")
            }
        }
        let m = TraaderModell(kilde: EnGang())
        await m.last()
        await m.last()
        #expect(m.skjerm?.antall == 6)
        #expect(m.feil != nil)
    }
}

@MainActor @Suite struct TraaderModellAvbruddOgFriskhetTests {
    private struct Avbrutt: TraadKilde {
        func hent() async throws -> TraadSkjerm { throw CancellationError() }
    }
    private struct URLAvbrutt: TraadKilde {
        func hent() async throws -> TraadSkjerm { throw URLError(.cancelled) }
    }
    private struct Teller: TraadKilde {
        let t = HentTeller()
        func hent() async throws -> TraadSkjerm { _ = await t.neste(); return TraadSkjerm(traader: [], nå: Date()) }
        func antall() async -> Int { await t.neste() - 1 }
    }

    @Test func avbruttHentingSetterIkkeFeil() async {
        for kilde in [Avbrutt() as any TraadKilde, URLAvbrutt()] {
            let m = TraaderModell(kilde: kilde)
            await m.last()
            #expect(m.feil == nil)
            #expect(m.skjerm == nil)
            #expect(m.sistHentet == nil)
            #expect(!m.henter)
        }
    }

    @Test func fanenHenterPåNyttBareNårForrigeHentingErGammel() async {
        var klokke = Date(timeIntervalSince1970: 1_760_000_000)
        let kilde = Teller()
        let m = TraaderModell(kilde: kilde, nå: { klokke })
        await m.lastHvisGammel()                    // aldri hentet: henter
        klokke.addTimeInterval(30)
        await m.lastHvisGammel()                    // 30 s: frisk, henter ikke
        klokke.addTimeInterval(40)
        await m.lastHvisGammel()                    // 70 s etter første: gammel, henter
        #expect(await kilde.antall() == 2)
    }
}

private actor HentTeller {
    private var n = 0
    func neste() -> Int { n += 1; return n }
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
