import Foundation
import Testing
@testable import AppCore

@Suite struct ArkVisningTests {
    private let t = Tilkobling(baseURL: URL(string: "https://ygg-v1.tail908368.ts.net:8444")!, token: "hemmelig-0123456789abcdef0123")
    private let utc = utcKalender()

    private func vis(_ tilstand: Innlogging.Tilstand, _ kontakt: Kontakt = .ukjent, lagret: Bool = false, feil: TilkoblingsFeil? = nil) -> ArkVisning {
        ArkVisning.fra(tilstand: tilstand, kontakt: kontakt, harLagret: lagret, handlingsFeil: feil, kalender: utc)
    }

    @Test func kobletOgIKontaktViserLampeOrdTidOgHeleAdressen() {
        let v = vis(.koblet(t), .ok(isoDato("2026-10-11T17:54:30Z")))
        #expect(v.lampe == .ok)
        #expect(v.ord == "TILKOBLET")
        #expect(v.detalj == "siste kontakt 17:54")
        #expect(v.adresse == "https://ygg-v1.tail908368.ts.net:8444")
        #expect(v.kanKobleFra && v.kanByttTilDemo && !v.kanKoble)
    }

    @Test func feiletHentingGirAvvikMedOrd() {
        let v = vis(.koblet(t), .feilet(kreverNyttToken: false))
        #expect(v.lampe == .avvik && v.ord == "FÅR IKKE KONTAKT" && v.detalj == nil)
        let u = vis(.koblet(t), .feilet(kreverNyttToken: true))
        #expect(u.lampe == .avvik && u.ord == "IKKE INNLOGGET")
    }

    @Test func førsteHentingErHenterUtenLampe() {
        let v = vis(.koblet(t), .ukjent)
        #expect(v.lampe == .ingen && v.ord == "HENTER")
    }

    @Test func demoHarIngenAdresseOgKanKobleTil() {
        let v = vis(.demo(rolig: false), lagret: true)
        #expect(v.ord == "DEMO" && v.adresse == nil)
        #expect(v.kanKoble && v.kanBrukLagret && !v.kanKobleFra)
        #expect(!vis(.demo(rolig: true), lagret: false).kanBrukLagret)
    }

    @Test func handlingsfeilenFølgerMedSåDenKanVises() {
        let v = vis(.koblet(t), .ok(Date()), feil: .kunneIkkeSlette)
        #expect(v.feil == .kunneIkkeSlette)
        #expect(v.kanKobleFra, "fortsatt koblet til: arket blir stående med feilen")
    }

    @Test func ingenVisningInneholderTokenet() {
        for v in [vis(.koblet(t), .ok(Date())), vis(.demo(rolig: false)), vis(.koblet(t), .feilet(kreverNyttToken: true), feil: .kunneIkkeSlette)] {
            var dumpet = ""
            dump(v, to: &dumpet)
            #expect(!dumpet.contains("hemmelig") && !"\(v)".contains("hemmelig"))
        }
    }

    @Test func kobleFraHarKonsekvenslinjeOgBekreftelse() {
        #expect(ArkVisning.kobleFraKonsekvens.contains("Keychain") && ArkVisning.kobleFraKonsekvens.contains("lime"))
        #expect(!ArkVisning.kobleFraTittel.isEmpty && ArkVisning.kobleFraBekreftelse == "Koble fra")
    }
}

@Suite struct TokenLengdeOgFeilplasseringTests {
    @Test func tokenLengdeTellerTrimmetOgKreverMinst24() {
        #expect(Tilkobling.tokenLengde("  abc\n") == 3)
        #expect(!Tilkobling.tokenLangNok(String(repeating: "a", count: 23)))
        #expect(Tilkobling.tokenLangNok(" " + String(repeating: "a", count: 24) + "\n"))
    }

    @Test func adressefeilStårVedAdressenOgRestenVedToken() {
        for f: TilkoblingsFeil in [.adresseMangler, .adresseUgyldig, .adresseIkkeHttps] { #expect(f.gjelderAdresse) }
        for f: TilkoblingsFeil in [.tokenMangler, .tokenForKort, .tokenUgyldigeTegn, .ikkeInnlogget, .ikkeNaabar, .tjenesteFeil(status: 500), .svarIkkeForstaatt, .kunneIkkeLagre] {
            #expect(!f.gjelderAdresse)
        }
    }

    @Test func lagreFeilenSierAtDenNyeIkkeBleLagret() {
        #expect(TilkoblingsFeil.kunneIkkeLagre.melding.contains("nye tilkoblingen ble ikke lagret"))
        #expect(!TilkoblingsFeil.kunneIkkeLagre.melding.contains("Ingenting er lagret"))
    }
}
