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
