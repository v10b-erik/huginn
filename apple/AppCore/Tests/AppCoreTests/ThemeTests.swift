import Foundation
import Testing
@testable import AppCore

/// Identiteten (design/identitet.md) som test: tekstrollene må holde WCAG-kontrast mot flaten de ligger på,
/// i begge moduser. Brekker noen dette ved å endre tokens.css, feiler testen i stedet for at det oppdages på skjermen.
@Suite struct ThemeTests {
    private func lineær(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private func luminans(_ c: Theme.RGBA) -> Double {
        0.2126 * lineær(c.r) + 0.7152 * lineær(c.g) + 0.0722 * lineær(c.b)
    }

    private func kontrast(_ a: Theme.RGBA, _ b: Theme.RGBA) -> Double {
        let (la, lb) = (luminans(a), luminans(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private let moduser: [(navn: String, palett: Theme.Palette)] = [("mørk", Theme.mork), ("lys", Theme.lys)]

    @Test func tekstrollerHolderWCAGMotFlaten() {
        for (navn, p) in moduser {
            let tekstroller: [(String, Theme.RGBA)] = [
                ("tekst", p.tekst), ("dempet", p.dempet), ("aksent", p.aksent), ("feil", p.feil), ("ok", p.ok),
            ]
            for (rolle, farge) in tekstroller {
                let k = kontrast(farge, p.kontrastflate)
                #expect(k >= 4.5, "\(navn): \(rolle) har kontrast \(k) mot kontrastflaten, trenger ≥ 4,5")
            }
        }
    }

    /// Båndene (FRA/KLASSE/RENT i godkjenningsbrikken, feltene på «Koble til», adressen i arket) ligger på en annen,
    /// mørkere flate enn glasset. `kontrastflateBand` er den EFFEKTIVE flaten bak tekst i et bånd, målt fra
    /// simulatorbilder. Uten denne målte testen bare mot glasset, og tre roller feilet stille i lys modus.
    @Test func tekstrollerHolderWCAGMotBåndflaten() {
        for (navn, p) in moduser {
            let tekstroller: [(String, Theme.RGBA)] = [
                ("tekst", p.tekst), ("dempet", p.dempet), ("aksent", p.aksent), ("feil", p.feil), ("ok", p.ok),
            ]
            for (rolle, farge) in tekstroller {
                let k = kontrast(farge, p.kontrastflateBand)
                #expect(k >= 4.5, "\(navn): \(rolle) har kontrast \(k) mot båndflaten, trenger ≥ 4,5")
            }
        }
    }

    @Test func hvitTekstPåAksentfyllHolderWCAG() {
        for (navn, p) in moduser {
            for (rolle, fyll) in [("fyll-1", p.aksentFyll1), ("fyll-2", p.aksentFyll2)] {
                let k = kontrast(p.paAksent, fyll)
                #expect(k >= 4.5, "\(navn): tekst på aksent-\(rolle) har kontrast \(k), trenger ≥ 4,5")
            }
        }
    }

    /// «Sender …»-flaten: tone (aksentTone over kontrastflaten) med tekst i `tekst`. Aksentfargen på tonen ga 3,6:1 i lys modus.
    @Test func tekstPåAksentToneHolderWCAG() {
        for (navn, p) in moduser {
            let a = p.aksentTone.a
            let flate = p.kontrastflate
            let tone = Theme.RGBA(
                p.aksentTone.r * a + flate.r * (1 - a), p.aksentTone.g * a + flate.g * (1 - a), p.aksentTone.b * a + flate.b * (1 - a)
            )
            #expect(kontrast(p.tekst, tone) >= 4.5, "\(navn): tekst på aksenttone har kontrast \(kontrast(p.tekst, tone))")
        }
    }

    /// Blandet flate: `lag` med dekkevne over `under` (som SwiftUI tegner det).
    private func over(_ lag: Theme.RGBA, alfa: Double, _ under: Theme.RGBA) -> Theme.RGBA {
        Theme.RGBA(lag.r * alfa + under.r * (1 - alfa), lag.g * alfa + under.g * (1 - alfa), lag.b * alfa + under.b * (1 - alfa))
    }

    /// AKSENT-tekst på aksent-toner: «GODKJENNING»-etiketten på godkjenningsbrikken (`krever1` øverst i gradienten) og valgt
    /// fane (`aksentTone` → `krever2`, teksten midt i flaten, så snittet av dekkevnene). Målt fra simulatorbilder i lys modus
    /// ga aksenten 3,86:1 på brikken og 4,04:1 på fanen før 2026-10-12; flatene under er modellert så de treffer det målet
    /// (modellen ga 3,90 og ca. 4,1). Tidligere dekket ingen test dette, bare `tekst` på tonen.
    @Test func aksentTekstPåAksentToneHolderWCAG() {
        for (navn, p) in moduser {
            let brikke = over(Theme.RGBA(p.krever1.r, p.krever1.g, p.krever1.b), alfa: p.krever1.a, p.kontrastflate)
            let midtAlfa = (p.aksentTone.a + p.krever2.a) / 2
            let fane = over(Theme.RGBA(p.aksentTone.r, p.aksentTone.g, p.aksentTone.b), alfa: midtAlfa, p.kontrastflate)
            #expect(kontrast(p.aksent, brikke) >= 4.5, "\(navn): aksent på godkjenningsbrikken har kontrast \(kontrast(p.aksent, brikke))")
            #expect(kontrast(p.aksent, fane) >= 4.5, "\(navn): aksent på valgt fane har kontrast \(kontrast(p.aksent, fane))")
        }
    }

    /// Avgjørelse 2026-10-12: lys aksent-tekst (FRA/KLASSE) skal ha klar margin til 4,5, ikke bare så vidt over (4,53).
    @Test func lysAksentTekstHarMarginMotBåndet() {
        #expect(kontrast(Theme.lys.aksent, Theme.lys.kontrastflateBand) >= 5.0)
        #expect(kontrast(Theme.lys.aksent, Theme.lys.kontrastflate) >= 5.0)
    }

    /// Knappefyllene (hvit tekst) skal ikke ha flyttet seg da tekstaksenten ble mørknet: de er egne tokens.
    @Test func knappefyllHarSammeKontrastSomFør() {
        #expect(abs(kontrast(Theme.lys.paAksent, Theme.lys.aksentFyll1) - 4.615) < 0.01)
        #expect(abs(kontrast(Theme.lys.paAksent, Theme.lys.aksentFyll2) - 5.264) < 0.01)
        #expect(abs(kontrast(Theme.mork.paAksent, Theme.mork.aksentFyll2) - 5.365) < 0.01)
    }

    @Test func svakErAldriTekst() {
        // --farge-svak er for ikke-tekst (slukket LED, tomme spor). Den skal ikke klare tekstkravet:
        // klarer den det, har noen gjort den til tekstfarge uten å si fra, eller skalaen har flyttet seg.
        for (navn, p) in moduser {
            #expect(kontrast(p.svak, p.kontrastflate) < 4.5, "\(navn): svak er blitt tekstfarge — bruk dempet")
        }
    }

    @Test func skalaeneErStigende() {
        let a = [Theme.Avstand.s1, Theme.Avstand.s2, Theme.Avstand.s3, Theme.Avstand.s4, Theme.Avstand.s5]
        #expect(a == a.sorted() && Set(a).count == a.count)
        #expect(Theme.Maal.beroringMin >= 44, "HIG: minste berøringsflate er 44 pt")
        #expect(Theme.Maal.knapp >= Theme.Maal.beroringMin && Theme.Maal.tab >= Theme.Maal.beroringMin)
    }
}
