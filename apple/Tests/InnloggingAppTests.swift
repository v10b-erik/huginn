import Testing
import Foundation
import Security
import AppCore
@testable import App

/// Keychain-testene bruker en egen `service` per test og rydder etter seg; det ekte elementet
/// (`no.huginn.traadflata`) røres aldri.
@Suite struct KeychainLagerTests {
    private static let hemmelig = "hemmelig-token-0123456789abcdef"

    private func lager() -> KeychainLager {
        KeychainLager(service: "no.huginn.test.\(UUID().uuidString)", account: "tilkobling", tillatHttpLoopback: false)
    }

    private func tilkobling(_ token: String = hemmelig, vert: String = "ygg.example") -> Tilkobling {
        Tilkobling(baseURL: URL(string: "https://\(vert):8444")!, token: token)
    }

    @Test func lesNårTomtGirNil() throws {
        let l = lager()
        #expect(try l.les() == nil)
    }

    @Test func rundtur() throws {
        let l = lager()
        defer { try? l.slett() }
        let t = tilkobling()
        try l.lagre(t)
        #expect(try l.les() == t)
    }

    @Test func lagreOverskriverUtenÅLageDuplikat() throws {
        let l = lager()
        defer { try? l.slett() }
        try l.lagre(tilkobling(vert: "forste.example"))
        let ny = tilkobling("annet-token-0123456789abcdefgh", vert: "andre.example")
        try l.lagre(ny)
        #expect(try l.les() == ny)
        // Nøyaktig ett element for denne service/account.
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: l.service,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny, kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]
        var svar: CFTypeRef?
        #expect(SecItemCopyMatching(q as CFDictionary, &svar) == errSecSuccess)
        #expect((svar as? [[String: Any]])?.count == 1)
    }

    @Test func slettFjernerOgToDobbeltSlettErIkkeFeil() throws {
        let l = lager()
        try l.lagre(tilkobling())
        try l.slett()
        #expect(try l.les() == nil)
        try l.slett()
    }

    @Test func elementetErDenneEnhetenOgIkkeICloud() throws {
        let l = lager()
        defer { try? l.slett() }
        try l.lagre(tilkobling())
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: l.service,
            kSecAttrAccount as String: l.account, kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnAttributes as String: true, kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var svar: CFTypeRef?
        #expect(SecItemCopyMatching(q as CFDictionary, &svar) == errSecSuccess)
        let attr = try #require(svar as? [String: Any])
        #expect(attr[kSecAttrAccessible as String] as? String == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        let synk = attr[kSecAttrSynchronizable as String]
        #expect((synk as? Bool) != true && (synk as? Int) != 1, "ikke iCloud-synk")
    }

    @Test func tokenetHavnerIkkeIUserDefaults() throws {
        let l = lager()
        defer { try? l.slett() }
        try l.lagre(tilkobling())
        let alt = UserDefaults.standard.dictionaryRepresentation()
        #expect(!"\(alt)".contains("hemmelig-token"), "tokenet lekket til UserDefaults")
        #expect(!alt.keys.contains { $0.contains("traadflata") || $0.contains("tilkobling") })
    }

    @Test func ødelagtInnholdGirTypetFeilUtenVerdier() throws {
        let l = lager()
        defer { try? l.slett() }
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: l.service,
            kSecAttrAccount as String: l.account, kSecAttrSynchronizable as String: false,
            kSecValueData as String: Data("ikke json, hemmelig".utf8),
        ]
        #expect(SecItemAdd(q as CFDictionary, nil) == errSecSuccess)
        do { _ = try l.les(); Issue.record("skulle kastet") }
        catch { #expect(error as? LagerFeil == .ugyldigInnhold) }
    }

    @Test func lagerbeskrivelsenHarIngenVerdier() throws {
        let l = lager()
        defer { try? l.slett() }
        try l.lagre(tilkobling())
        var dumpet = ""
        dump(l, to: &dumpet)
        for tekst in ["\(l)", String(reflecting: l), dumpet] { #expect(!tekst.contains("hemmelig")) }
    }

    @Test func feilenBærerBareStatus() {
        let f = LagerFeil.keychain(status: errSecAuthFailed)
        #expect(!"\(f)".contains("hemmelig"))
    }
}

@MainActor @Suite struct InnloggingModellTests {
    private let token = "tok-0123456789abcdef0123"
    private let adresse = "https://ygg.example:8444"

    private func modell(_ lager: MinneLager = MinneLager(), bekreft: @escaping InnloggingModell.Bekreft) -> InnloggingModell {
        let m = InnloggingModell(lager: lager, tillatHttpLoopback: false, bekreft: bekreft)
        m.start(argumenter: [], miljo: [:], tillatLive: false)
        return m
    }

    @Test func bekreftetTilkoblingLagresOgGirKoblet() async {
        let l = MinneLager()
        let m = modell(l) { _ in }
        await m.koble(adresse: adresse, token: token)
        guard case .koblet(let t) = m.tilstand else { Issue.record("forventet koblet, fikk \(m.tilstand)"); return }
        #expect(t.token == token && t.adresse == adresse)
        #expect(l.innhold == t)
    }

    @Test func avvistTokenLagrerIkkeNoe() async {
        let l = MinneLager()
        let m = modell(l) { _ in throw TilkoblingsFeil.ikkeInnlogget }
        await m.koble(adresse: adresse, token: token)
        #expect(m.tilstand == .ikkeKoblet(feil: .ikkeInnlogget))
        #expect(l.innhold == nil && l.antallSkrivinger == 0)
    }

    @Test func ugyldigInndataKallerAldriNettverket() async {
        let kall = Teller()
        let m = modell { _ in await kall.øk() }
        await m.koble(adresse: adresse, token: "kort")
        #expect(m.tilstand == .ikkeKoblet(feil: .tokenForKort))
        #expect(await kall.antall == 0)
    }

    @Test func tilstandenErKoblerMensBekreftelsenPågår() async throws {
        let m = modell { _ in try await Task.sleep(for: .milliseconds(300)) }
        let oppgave = Task { await m.koble(adresse: adresse, token: token) }
        try await Task.sleep(for: .milliseconds(60))
        #expect(m.tilstand == .kobler)
        await oppgave.value
        if case .koblet = m.tilstand {} else { Issue.record("forventet koblet") }
    }

    @Test func avbruttBekreftelseLeggerIkkeSkjermenIKobler() async {
        let l = MinneLager()
        let m = modell(l) { _ in throw CancellationError() }
        await m.koble(adresse: adresse, token: token)
        #expect(m.tilstand == .ikkeKoblet(feil: .ikkeNaabar))
        #expect(l.innhold == nil)
    }

    @Test func skriveFeilEtterBekreftelseGirIkkeKobletMedFeil() async {
        let l = MinneLager()
        l.feilVed(.lagre, .keychain(status: -34018))
        let m = modell(l) { _ in }
        await m.koble(adresse: adresse, token: token)
        #expect(m.tilstand == .ikkeKoblet(feil: .kunneIkkeLagre))
        #expect(l.innhold == nil)
    }

    @Test func generasjonenØkerNårHvaSomVisesEndres() async {
        let m = modell { _ in }
        let g0 = m.generasjon
        await m.koble(adresse: adresse, token: token)
        #expect(m.generasjon > g0)
        let g1 = m.generasjon
        m.kobleFra()
        #expect(m.generasjon > g1)
        #expect(m.tilstand == .ikkeKoblet(feil: nil))
    }

    @Test func modellenLekkerIkkeTokenet() async {
        let m = modell { _ in }
        await m.koble(adresse: adresse, token: "hemmelig-0123456789abcdef0123")
        var dumpet = ""
        dump(m.tilstand, to: &dumpet)
        #expect(!dumpet.contains("hemmelig") && !"\(m.tilstand)".contains("hemmelig"))
    }
}

private actor Teller {
    private(set) var antall = 0
    func øk() { antall += 1 }
}
