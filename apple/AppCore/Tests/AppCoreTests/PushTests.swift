import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import AppCore

@Suite struct PushTests {
    private let hex64 = String(repeating: "ab12", count: 16)
    private let bearer = "tok-0123456789abcdef01234567"
    private func tokenHex() -> PushToken { PushToken(hex: hex64)! }

    // MARK: - PushRute

    private func info(_ type: Any, _ id: Any) -> [AnyHashable: Any] { ["kjerne": ["type": type, "id": id], "aps": ["alert": "x"]] }

    @Test func godkjenningMedGyldigIdRutes() {
        #expect(PushRute.parse(userInfo: info("godkjenning", "kort-123_AB")) == .godkjenning("kort-123_AB"))
    }

    @Test func alleOgrePåUpåliteligInndataGirUkjent() {
        let ugyldige: [[AnyHashable: Any]] = [
            [:], ["kjerne": "tekst"], ["kjerne": ["type": "godkjenning"]], ["kjerne": ["id": "abcdef123"]],
            info("annet", "abcdef123"), info("Godkjenning", "abcdef123"), info("godkjenning", "abc"),
            info("godkjenning", String(repeating: "a", count: 65)), info("godkjenning", "../etc/passwd"),
            info("godkjenning", "abc def123"), info("godkjenning", "abcdéf123"), info("godkjenning", "abcdef\n"),
            info("godkjenning", 123456), info(5, "abcdef123"),
        ]
        for u in ugyldige { #expect(PushRute.parse(userInfo: u) == .ukjent) }
    }

    // MARK: - PushToken

    @Test func hexFraData() throws {
        let t = try #require(PushToken(data: Data((0..<32).map { UInt8($0 * 8) })))
        #expect(t.fingeravtrykk == "000810…f0f8")
        #expect(PushToken(data: Data()) == nil)
        #expect(PushToken(data: Data(repeating: 1, count: 101)) == nil)
    }

    @Test func hexValideres() {
        #expect(PushToken(hex: hex64) != nil)
        #expect(PushToken(hex: String(hex64.dropLast())) == nil)
        #expect(PushToken(hex: String(repeating: "g", count: 64)) == nil)
        #expect(PushToken(hex: String(repeating: "a", count: 201)) == nil)
    }

    @Test func fingeravtrykkOgIngenLekkasje() throws {
        let t = try #require(PushToken(hex: "abcdef" + String(repeating: "0", count: 54) + "1234"))
        #expect(t.fingeravtrykk == "abcdef…1234")
        for s in [t.description, t.debugDescription, String(describing: t), "\(t)"] { #expect(!s.contains(t.hex)) }
        var dumpet = ""
        dump(t, to: &dumpet)
        #expect(!dumpet.contains(t.hex))
    }

    // MARK: - registrerPush

    private func kropp(_ r: URLRequest) -> Data? {
        if let b = r.httpBody { return b }
        guard let s = r.httpBodyStream else { return nil }
        s.open(); defer { s.close() }
        var d = Data(); var buf = [UInt8](repeating: 0, count: 1024)
        while s.hasBytesAvailable { let n = s.read(&buf, maxLength: buf.count); if n <= 0 { break }; d.append(buf, count: n) }
        return d
    }

    private func klient(_ handler: @escaping StubURLProtocol.Handler) -> (TraadflataKlient, String) {
        let s = StubURLProtocol.oppsett(handler: handler)
        return (TraadflataKlient(baseURL: s.baseURL, token: bearer, session: s.session), s.host)
    }

    @Test func sendterPostMedBearerOgNøyaktigKropp() async throws {
        let (k, host) = klient { _ in StubSvar(status: 200, body: Data("{\"ok\":true}".utf8)) }
        try await k.registrerPush(token: tokenHex(), miljo: .sandbox)
        let r = try #require(StubURLProtocol.sett(host: host).first)
        #expect(StubURLProtocol.sett(host: host).count == 1)
        #expect(r.httpMethod == "POST")
        #expect(r.url?.path == "/api/push/token")
        #expect(r.value(forHTTPHeaderField: "Authorization") == "Bearer \(bearer)")
        #expect(r.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let d = try #require(kropp(r))
        let j = try #require(try JSONSerialization.jsonObject(with: d) as? [String: String])
        #expect(j == ["token": hex64, "miljo": "sandbox"])
    }

    @Test func produksjonsmiljøSendesSomProduksjon() async throws {
        let (k, host) = klient { _ in StubSvar(status: 200, body: Data("{\"ok\":true}".utf8)) }
        try await k.registrerPush(token: tokenHex(), miljo: .produksjon)
        let første = try #require(StubURLProtocol.sett(host: host).first)
        let d = try #require(kropp(første))
        #expect(String(decoding: d, as: UTF8.self).contains("\"miljo\":\"produksjon\""))
    }

    @Test func feilMapperTilTraadflataFeilUtenTokenOgUtenRetry() async throws {
        let t = try #require(PushToken(hex: hex64))
        let (k401, h401) = klient { _ in StubSvar(status: 401, body: Data("{}".utf8)) }
        await #expect(throws: TraadflataFeil.ikkeInnlogget) { try await k401.registrerPush(token: t, miljo: .sandbox) }
        #expect(StubURLProtocol.sett(host: h401).count == 1)

        let (k500, h500) = klient { _ in StubSvar(status: 500, body: Data("{\"error\":\"boom\"}".utf8)) }
        await #expect(throws: TraadflataFeil.http(status: 500, melding: "boom")) { try await k500.registrerPush(token: t, miljo: .sandbox) }
        #expect(StubURLProtocol.sett(host: h500).count == 1)

        let (kNett, hNett) = klient { _ in throw URLError(.notConnectedToInternet) }
        do { try await kNett.registrerPush(token: t, miljo: .sandbox); Issue.record("skulle feilet") } catch {
            #expect(!String(describing: error).contains(hex64))
        }
        #expect(StubURLProtocol.sett(host: hNett).count == 1)
    }
}

@Suite struct PushBeslutningTests {
    @Test func tillatelseBareForLiveOgIkkeAvgjort() {
        #expect(PushTillatelse.skalSpoerre(status: .ikkeAvgjort, erLive: true, hoppOver: false))
        for s: PushTillatelse.Status in [.avslatt, .tillatt, .annet] {
            #expect(!PushTillatelse.skalSpoerre(status: s, erLive: true, hoppOver: false))
        }
        #expect(!PushTillatelse.skalSpoerre(status: .ikkeAvgjort, erLive: false, hoppOver: false))
        #expect(!PushTillatelse.skalSpoerre(status: .ikkeAvgjort, erLive: true, hoppOver: true))
    }

    @Test func rutebeslutning() {
        #expect(PushRute.utfall(id: "kort-aaa", ventende: ["kort-aaa", "x"], hentingLyktes: true) == .fremhev("kort-aaa"))
        #expect(PushRute.utfall(id: "kort-aaa", ventende: ["andre-1"], hentingLyktes: true) == .alleredeAvgjort)
        #expect(PushRute.utfall(id: "kort-aaa", ventende: [], hentingLyktes: true) == .alleredeAvgjort)
        // Tom/ingen skjerm før første henting og hentefeil er aldri «avgjort».
        #expect(PushRute.utfall(id: "kort-aaa", ventende: nil, hentingLyktes: false) == .ingentingEnnaa)
        #expect(PushRute.utfall(id: "kort-aaa", ventende: nil, hentingLyktes: true) == .ingentingEnnaa)
        #expect(PushRute.utfall(id: "kort-aaa", ventende: [], hentingLyktes: false) == .ingentingEnnaa)
        #expect(PushRute.utfall(id: "kort-aaa", ventende: ["kort-aaa"], hentingLyktes: false) == .ingentingEnnaa)
    }
}
