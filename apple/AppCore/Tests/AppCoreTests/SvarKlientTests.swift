import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import AppCore

/// `TraadflataKlient.svar`: forespørselens form, hver statuskode, og at et nettverksbrudd gir ÉN forsendelse.
/// Tokenet står aldri i et `#expect`-uttrykk: en rød test skal ikke skrive det i utskriften.
@Suite struct SvarKlientTests {
    private let token = "tok-0123456789abcdef01234567"

    private func klient(handler: @escaping StubURLProtocol.Handler) -> (TraadflataKlient, String) {
        let s = StubURLProtocol.oppsett(handler: handler)
        return (TraadflataKlient(baseURL: s.baseURL, token: token, session: s.session), s.host)
    }

    private func kropp(_ r: URLRequest) -> Data? {
        if let b = r.httpBody { return b }
        guard let strøm = r.httpBodyStream else { return nil }
        strøm.open()
        defer { strøm.close() }
        var data = Data()
        var buf = [UInt8](repeating: 0, count: 1024)
        while strøm.hasBytesAvailable {
            let n = strøm.read(&buf, maxLength: buf.count)
            if n <= 0 { break }
            data.append(buf, count: n)
        }
        return data
    }

    private func tekstKropp(_ r: URLRequest) -> String? {
        kropp(r).flatMap { String(data: $0, encoding: .utf8) }
    }

    private func json(_ status: Int, _ tekst: String = "{\"ok\":true}") -> StubSvar {
        StubSvar(status: status, body: Data(tekst.utf8))
    }

    // MARK: - forespørselens form

    @Test func sendterPostMedRiktigStiHeadereOgNøyaktigKropp() async throws {
        let (k, host) = klient { _ in json(200) }
        let utfall = try await k.svar(kortId: "demo-alarm_01", key: "approve")
        #expect(utfall == .avgjort)
        let r = try #require(StubURLProtocol.sett(host: host).first)
        #expect(r.httpMethod == "POST")
        #expect(r.url?.path == "/api/godkjenning/demo-alarm_01")
        #expect(r.url?.query == nil)
        let bearerOk = r.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)"
        #expect(bearerOk)
        #expect(r.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(r.value(forHTTPHeaderField: "Origin") == nil)
        let tekst = try #require(tekstKropp(r))
        #expect(tekst == #"{"key":"approve"}"#)
    }

    @Test func avslåSenderDeny() async throws {
        let (k, host) = klient { _ in json(200) }
        _ = try await k.svar(kortId: "abcdef12", key: "deny")
        let r = try #require(StubURLProtocol.sett(host: host).first)
        let tekst = try #require(tekstKropp(r))
        #expect(tekst == #"{"key":"deny"}"#)
    }

    @Test func nøkkelenKodesSomJsonOgBlirIkkeEnDelAvStien() async throws {
        let (k, host) = klient { _ in json(400, #"{"error":"ukjent valg"}"#) }
        let utfall = try await k.svar(kortId: "abcdef12", key: "a\"b/../c")
        #expect(utfall == .ugyldigValg)
        let r = try #require(StubURLProtocol.sett(host: host).first)
        #expect(r.url?.path == "/api/godkjenning/abcdef12")
        let tekst = try #require(tekstKropp(r))
        #expect(tekst.hasPrefix(#"{"key":"a\"b"#))
    }

    @Test func baseURLMedStiBevares() async throws {
        let s = StubURLProtocol.oppsett { _ in json(200) }
        let k = TraadflataKlient(baseURL: s.baseURL.appendingPathComponent("flata/"), token: token, session: s.session)
        _ = try await k.svar(kortId: "abcdef12", key: "approve")
        let r = try #require(StubURLProtocol.sett(host: s.host).first)
        #expect(r.url?.path == "/flata/api/godkjenning/abcdef12")
    }

    // MARK: - kort-id

    @Test(arguments: [
        "", "abc", "abcde", "kort id 1", "../../api/naa", "abc/def12", "abc?x=1&y=2", "abc%2Fdef1", "abcdef1\n", "æøåæøåæøå",
        String(repeating: "a", count: 65), "abc#frag12", "abc.def12",
    ])
    func ugyldigKortIdSendesAldri(id: String) async throws {
        let (k, host) = klient { _ in json(200) }
        await #expect(throws: TraadflataFeil.ugyldigKortId) { try await k.svar(kortId: id, key: "approve") }
        #expect(StubURLProtocol.sett(host: host).isEmpty)
    }

    @Test(arguments: ["abcdef", "a-b_c9", "ABCDEF-0123", String(repeating: "x", count: 64), "demo-alarm", "7f3c1e2a-9d4b-4c8e-a1f0-5b6d7e8f9a0b"])
    func gyldigKortIdGårTil(id: String) async throws {
        let (k, host) = klient { _ in json(200) }
        _ = try await k.svar(kortId: id, key: "approve")
        #expect(StubURLProtocol.sett(host: host).count == 1)
    }

    @Test func tomNøkkelSendesAldri() async throws {
        let (k, host) = klient { _ in json(200) }
        #expect(try await k.svar(kortId: "abcdef12", key: "") == .ugyldigValg)
        #expect(StubURLProtocol.sett(host: host).isEmpty)
    }

    // MARK: - statuskoder

    @Test func status200ErAvgjort() async throws {
        let (k, _) = klient { _ in json(200) }
        #expect(try await k.svar(kortId: "abcdef12", key: "approve") == .avgjort)
    }

    @Test func status200MedUtolketKroppErLikevelAvgjort() async throws {
        let (k, _) = klient { _ in json(200, "ikke json") }
        #expect(try await k.svar(kortId: "abcdef12", key: "approve") == .avgjort)
    }

    @Test func status409BærerServerensTekst() async throws {
        let (k, _) = klient { _ in json(409, #"{"error":"kortet er allerede avslått"}"#) }
        #expect(try await k.svar(kortId: "abcdef12", key: "approve") == .alleredeAvgjort("kortet er allerede avslått"))
    }

    @Test func status409UtenTekst() async throws {
        let (k, _) = klient { _ in json(409, "") }
        #expect(try await k.svar(kortId: "abcdef12", key: "approve") == .alleredeAvgjort(nil))
    }

    @Test func status404ErUkjentKort() async throws {
        let (k, _) = klient { _ in json(404, #"{"error":"ukjent kort"}"#) }
        #expect(try await k.svar(kortId: "abcdef12", key: "approve") == .ukjentKort)
    }

    @Test func status400ErUgyldigValg() async throws {
        let (k, _) = klient { _ in json(400, #"{"error":"key mangler"}"#) }
        #expect(try await k.svar(kortId: "abcdef12", key: "approve") == .ugyldigValg)
    }

    @Test func status401ErIkkeInnlogget() async throws {
        let (k, _) = klient { _ in json(401, "ukjent token") }
        await #expect(throws: TraadflataFeil.ikkeInnlogget) { try await k.svar(kortId: "abcdef12", key: "approve") }
    }

    @Test(arguments: [403, 500, 502, 504])
    func andreStatuserKastesSomHttp(status: Int) async throws {
        let (k, host) = klient { _ in json(status, #"{"error":"x"}"#) }
        await #expect(throws: TraadflataFeil.http(status: status, melding: "x")) {
            try await k.svar(kortId: "abcdef12", key: "approve")
        }
        #expect(StubURLProtocol.sett(host: host).count == 1, "ingen retry på 5xx")
    }

    // MARK: - nettverk

    @Test(arguments: [URLError.Code.timedOut, .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cancelled])
    func nettverksfeilGirÉnForsendelseOgIngenRetry(kode: URLError.Code) async throws {
        let (k, host) = klient { _ in throw URLError(kode) }
        do {
            _ = try await k.svar(kortId: "abcdef12", key: "approve")
            Issue.record("skulle kastet")
        } catch let feil as TraadflataFeil {
            guard case .nettverk = feil else { Issue.record("feil type feil"); return }
        }
        #expect(StubURLProtocol.sett(host: host).count == 1, "nøyaktig én forsendelse, ingen retry")
    }

    // MARK: - tokenet

    @Test func tokenetStårIkkeIFeilmeldingerEllerBeskrivelse() async throws {
        let (k, _) = klient { _ in throw URLError(.timedOut) }
        do { _ = try await k.svar(kortId: "abcdef12", key: "approve") } catch {
            #expect(!String(describing: error).contains(token))
            #expect(!String(reflecting: error).contains(token))
        }
        #expect(!String(describing: k).contains(token))
        #expect(!String(reflecting: k).contains(token))
        var dump = ""
        Swift.dump(k, to: &dump)
        #expect(!dump.contains(token))
    }
}
