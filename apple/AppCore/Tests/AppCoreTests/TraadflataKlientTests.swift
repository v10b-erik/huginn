import Foundation
import Testing
@testable import AppCore

@Suite struct TraadflataKlientTests {
    private func klient(
        token: String = "tok-0123456789abcdef01234567",
        basePath: String = "",
        handler: @escaping StubURLProtocol.Handler
    ) -> (TraadflataKlient, String) {
        let s = StubURLProtocol.oppsett(handler: handler)
        let base = basePath.isEmpty ? s.baseURL : s.baseURL.appendingPathComponent(basePath)
        return (TraadflataKlient(baseURL: base, token: token, session: s.session), s.host)
    }

    private func dato(_ iso: String) -> Date {
        try! Date(iso, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    // MARK: - ruter og auth

    @Test func hentTraaderBrukerRiktigRuteMetodeOgBearer() async throws {
        let (k, host) = klient { _ in StubSvar(status: 200, body: try Fixtur.data("traader.json")) }
        _ = try await k.hentTraader()
        let r = try #require(StubURLProtocol.sett(host: host).first)
        #expect(r.httpMethod == "GET")
        #expect(r.url?.path == "/api/traader")
        #expect(r.url?.query == nil)
        #expect(r.value(forHTTPHeaderField: "Authorization") == "Bearer tok-0123456789abcdef01234567")
    }

    @Test func hentNaaBrukerRiktigRuteMetodeOgBearer() async throws {
        let (k, host) = klient { _ in StubSvar(status: 200, body: try Fixtur.data("naa.json")) }
        _ = try await k.hentNaa()
        let r = try #require(StubURLProtocol.sett(host: host).first)
        #expect(r.httpMethod == "GET")
        #expect(r.url?.path == "/api/naa")
        #expect(r.value(forHTTPHeaderField: "Authorization") == "Bearer tok-0123456789abcdef01234567")
    }

    @Test func baseURLMedStiOgSluttskråstrekGirIkkeDobbeltSkråstrek() async throws {
        let (k, host) = klient(basePath: "flata/") { _ in StubSvar(status: 200, body: Data("[]".utf8)) }
        _ = try await k.hentTraader()
        let r = try #require(StubURLProtocol.sett(host: host).first)
        #expect(r.url?.path == "/flata/api/traader")
    }

    // MARK: - /api/traader

    @Test func dekoderTraaderFraInnspiltSvar() async throws {
        let (k, _) = klient { _ in StubSvar(status: 200, body: try Fixtur.data("traader.json")) }
        let traader = try await k.hentTraader()
        #expect(traader.count == 3)

        let a = traader[0]
        #expect(a.id == "6f1c2a9e-3b7d-4e0a-9c11-5d2f8a7b0c34")
        #expect(a.tittel == "Bygg trådflataklient i AppCore")
        #expect(a.sistAktiv == Date(timeIntervalSince1970: 1_760_183_456.789))
        #expect(a.holder == TraadHolder(type: .plattform, status: "working", aktiv: true, kilde: "einherjar"))
        #expect(a.prosjekt?.jd == "21.22")
        #expect(a.prosjekt?.label == "21.22 huginn")
        #expect(a.ko == 2)
        #expect(a.status == .holdt)
    }

    @Test func manglendeValgfrieFeltFeilerIkke() async throws {
        let (k, _) = klient { _ in StubSvar(status: 200, body: try Fixtur.data("traader.json")) }
        let b = try await k.hentTraader()[1]
        #expect(b.holder == nil)
        #expect(b.arkivert == nil)
        #expect(b.ko == nil)
        #expect(b.prosjekt?.id == nil)
        #expect(b.prosjekt?.label == "Basic")
        #expect(b.status == .parkert)
    }

    @Test func ukjenteFeltOgUkjentHoldertypeIgnoreresTolerant() async throws {
        let (k, _) = klient { _ in StubSvar(status: 200, body: try Fixtur.data("traader.json")) }
        let c = try await k.hentTraader()[2]
        #expect(c.holder?.type == .ukjent("robot"))
        #expect(c.holder?.aktiv == false)
        #expect(c.arkivert == Date(timeIntervalSince1970: 1_759_950_000))
        #expect(c.status == .arkivert)
    }

    @Test func tomTraadlisteGirTomListe() async throws {
        let (k, _) = klient { _ in StubSvar(status: 200, body: Data("[]".utf8)) }
        #expect(try await k.hentTraader().isEmpty)
    }

    @Test func traadUtenIdGirDekodingsfeil() async {
        let (k, _) = klient { _ in StubSvar(status: 200, body: Data(#"[{"tittel":"x","sistAktiv":1}]"#.utf8)) }
        await #expect {
            try await k.hentTraader()
        } throws: { feil in
            if case TraadflataFeil.dekoding = feil { return true }
            return false
        }
    }

    // MARK: - /api/naa

    @Test func dekoderNaaFraInnspiltSvar() async throws {
        let (k, _) = klient { _ in StubSvar(status: 200, body: try Fixtur.data("naa.json")) }
        let n = try await k.hentNaa()

        #expect(n.kort.count == 2)
        #expect(n.kort[0].id == "a1b2c3d4e5f6")
        #expect(n.kort[0].describe == "Deploy huginn 6c84734 til ygg-v1")
        #expect(n.kort[0].expiresAt == dato("2026-10-12T08:00:00.000Z"))
        #expect(n.kort[0].actions?.map(\.key) == ["approve", "deny"])
        #expect(n.kort[0].threadKey == "mission:ko-abc")
        #expect(n.kort[1].actions == nil)
        #expect(n.kort[1].expiresAt == nil)

        #expect(n.avvik.count == 2)
        #expect(n.avvik[0].ts == nil)
        #expect(n.avvik[0].id == "tjeneste:forgejo")
        #expect(n.avvik[1].ts == dato("2026-10-11T19:30:15.123Z"))

        #expect(n.kalender.map(\.tittel) == ["Tannlege", "Ferie"])
        #expect(n.kalender[1].heleDagen == true)
        #expect(n.paminnelser.first?.tekst == "Ring banken")
        #expect(n.pausetTil == dato("2026-10-12T06:00:00.000Z"))
        #expect(n.jobber == 7)
    }

    @Test func naaMedManglendeListerOgUkjenteFeltGirTommeLister() async throws {
        let (k, _) = klient { _ in StubSvar(status: 200, body: try Fixtur.data("naa-minimal.json")) }
        let n = try await k.hentNaa()
        #expect(n == Naa())
        #expect(n.pausetTil == nil)
    }

    @Test func isoDatoUtenBrøksekunderGodtas() async throws {
        let body = #"{"paminnelser":[{"tekst":"x","ts":"2026-10-11T22:00:00Z"}]}"#
        let (k, _) = klient { _ in StubSvar(status: 200, body: Data(body.utf8)) }
        let p = try await k.hentNaa().paminnelser
        #expect(p.first?.ts == Date(timeIntervalSince1970: 1_791_756_000))
    }

    // MARK: - feil

    @Test func ukjentTokenGirIkkeInnlogget() async {
        let (k, _) = klient { _ in
            StubSvar(status: 401, body: try Fixtur.data("feil-ukjent-token.txt"), headers: ["Content-Type": "text/plain"])
        }
        await #expect(throws: TraadflataFeil.ikkeInnlogget) { try await k.hentNaa() }
        await #expect(throws: TraadflataFeil.ikkeInnlogget) { try await k.hentTraader() }
    }

    @Test func httpFeilBærerStatusOgServerensMelding() async {
        let (k, _) = klient { _ in StubSvar(status: 404, body: try Fixtur.data("feil-json.json")) }
        await #expect(throws: TraadflataFeil.http(status: 404, melding: "ukjent eller tvetydig tråd")) {
            try await k.hentTraader()
        }
    }

    @Test func httpFeilUtenJsonMeldingGirNilMelding() async {
        let (k, _) = klient { _ in StubSvar(status: 502, body: Data("<html>bad gateway</html>".utf8)) }
        await #expect(throws: TraadflataFeil.http(status: 502, melding: nil)) { try await k.hentNaa() }
    }

    @Test func ugyldigJsonGirDekodingsfeilUtenInnholdet() async {
        let (k, _) = klient { _ in StubSvar(status: 200, body: Data("hemmelig samtaletekst".utf8)) }
        await #expect {
            try await k.hentNaa()
        } throws: { feil in
            guard case TraadflataFeil.dekoding(let melding) = feil else { return false }
            return !melding.contains("hemmelig")
        }
    }

    @Test func nettverksfeilPakkesInn() async {
        let (k, _) = klient { _ in throw URLError(.notConnectedToInternet) }
        await #expect {
            try await k.hentTraader()
        } throws: { feil in
            if case TraadflataFeil.nettverk = feil { return true }
            return false
        }
    }

    // MARK: - kodek

    @Test func modellenRundtureMedKoderOgDekoder() throws {
        let original = Naa(
            kort: [NaaKort(id: "k1", name: "deploy", describe: "d", status: "pending", expiresAt: dato("2026-10-12T08:00:00.123Z"), threadKey: nil, actions: nil)],
            avvik: [NaaAvvik(art: "jobb", navn: "n", tekst: "t", ts: dato("2026-10-11T10:00:00.500Z"), lenke: nil)],
            pausetTil: dato("2026-10-12T06:00:00.000Z"),
            jobber: 3
        )
        let data = try TraadflataKlient.koder().encode(original)
        #expect(try TraadflataKlient.dekoder().decode(Naa.self, from: data) == original)
    }
}
