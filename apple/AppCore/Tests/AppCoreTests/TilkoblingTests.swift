import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import AppCore

@Suite struct TilkoblingTests {
    private let token = "tok-0123456789abcdef0123"  // 24 tegn
    private let adresse = "https://ygg-v1.tail908368.ts.net:8444"

    private func feil(_ adresse: String, _ token: String, loopback: Bool = false) -> TilkoblingsFeil? {
        do { _ = try Tilkobling.fra(adresse: adresse, token: token, tillatHttpLoopback: loopback); return nil }
        catch { return error }
    }

    @Test func gyldigTilkoblingNormaliseres() throws {
        let t = try Tilkobling.fra(adresse: "  https://Ygg-V1.Tail908368.ts.net:8444///\n", token: "  \(token)\n")
        #expect(t.baseURL.absoluteString == "https://ygg-v1.tail908368.ts.net:8444")
        #expect(t.token == token)
        #expect(t.vert == "ygg-v1.tail908368.ts.net")
    }

    @Test func standardAdresseErGyldig() throws {
        _ = try Tilkobling.fra(adresse: Tilkobling.standardAdresse, token: token)
    }

    @Test func stiBeholdesMenSluttskråstrekFjernes() throws {
        let t = try Tilkobling.fra(adresse: "https://x.example/flata/", token: token)
        #expect(t.baseURL.absoluteString == "https://x.example/flata")
    }

    @Test func tomOgUgyldigAdresse() {
        #expect(feil("", token) == .adresseMangler)
        #expect(feil("   \n", token) == .adresseMangler)
        #expect(feil("https://", token) == .adresseUgyldig)
        #expect(feil("https:///sti", token) == .adresseUgyldig)
        #expect(feil("https://bruker:passord@x.example", token) == .adresseUgyldig)
        #expect(feil("https://x.example?a=b", token) == .adresseUgyldig)
        #expect(feil("https://x.example#del", token) == .adresseUgyldig)
        #expect(feil("https://ikke en vert", token) == .adresseUgyldig)
    }

    @Test func kreverHttps() {
        #expect(feil("http://x.example", token) == .adresseIkkeHttps)
        #expect(feil("ygg-v1.tail908368.ts.net:8444", token) == .adresseIkkeHttps, "uten skjema")
        #expect(feil("ygg.example", token) == .adresseIkkeHttps)
        #expect(feil("file:///etc/passwd", token) == .adresseIkkeHttps)
        #expect(feil("ftp://x.example", token) == .adresseIkkeHttps)
    }

    @Test func httpBareForLoopbackOgBareNårTillatt() throws {
        #expect(feil("http://localhost:3030", token) == .adresseIkkeHttps, "release")
        #expect(feil("http://127.0.0.1:3030", token) == .adresseIkkeHttps, "release")
        #expect(try Tilkobling.fra(adresse: "http://localhost:3030", token: token, tillatHttpLoopback: true).vert == "localhost")
        #expect(try Tilkobling.fra(adresse: "http://127.0.0.1:3030/", token: token, tillatHttpLoopback: true).adresse == "http://127.0.0.1:3030")
        #expect(feil("http://x.example", token, loopback: true) == .adresseIkkeHttps)
        #expect(feil("http://localhost.evil.example", token, loopback: true) == .adresseIkkeHttps)
        #expect(feil("http://192.168.1.5", token, loopback: true) == .adresseIkkeHttps)
    }

    @Test func tokenReglene() {
        #expect(feil(adresse, "") == .tokenMangler)
        #expect(feil(adresse, "  \n") == .tokenMangler)
        #expect(feil(adresse, String(repeating: "a", count: 23)) == .tokenForKort)
        #expect(feil(adresse, String(repeating: "a", count: 24)) == nil)
        #expect(feil(adresse, "tok med mellomrom 0123456789abc") == .tokenUgyldigeTegn)
        #expect(feil(adresse, "tok-0123456789\nabcdef0123456") == .tokenUgyldigeTegn, "linjeskift ville kunne sprengt headeren")
        #expect(feil(adresse, "tøk-0123456789abcdef0123456") == .tokenUgyldigeTegn)
    }

    @Test func adressenSjekkesFørTokenet() {
        #expect(feil("", "") == .adresseMangler)
    }

    @Test func rekkefølgenGirEnFeilAvGangenMedNorskMelding() {
        for f: TilkoblingsFeil in [.adresseMangler, .adresseUgyldig, .adresseIkkeHttps, .tokenMangler, .tokenForKort, .tokenUgyldigeTegn,
                                   .ikkeInnlogget, .ikkeNaabar, .tjenesteFeil(status: 503), .svarIkkeForstaatt,
                                   .kunneIkkeLagre, .kunneIkkeLese, .kunneIkkeSlette] {
            #expect(!f.melding.isEmpty && !f.ord.isEmpty)
            #expect(f.ord == f.ord.uppercased())
        }
        #expect(TilkoblingsFeil.tokenForKort.melding.contains("24"), "sier rett ut at serveren ignorerer korte tokens")
        #expect(TilkoblingsFeil.ikkeInnlogget.ord == "IKKE INNLOGGET")
        #expect(TilkoblingsFeil.ikkeInnlogget.melding.contains("ukjent for trådflata"))
        #expect(TilkoblingsFeil.ikkeNaabar.ord == "KAN IKKE KOBLE TIL")
        #expect(TilkoblingsFeil.ikkeNaabar.melding.contains("tailnettet"))
        #expect(TilkoblingsFeil.tjenesteFeil(status: 503).melding.contains("503"))
    }

    @Test func feilmeldingerLekkerAldriInnskrevetVerdi() {
        // Adressen og tokenet er unike strenger; ingen feil de gir skal inneholde dem.
        let unik = "hemmelig-ABCDEF"
        let forsøk: [(String, String)] = [
            ("https://\(unik).example?x=1", token), ("http://\(unik).example", token), ("\(unik)", token),
            (adresse, unik), (adresse, "\(unik) mellomrom"), (adresse, "\(unik)\n\(unik)"),
        ]
        for (a, t) in forsøk {
            guard let f = feil(a, t) else { continue }
            #expect(!f.melding.contains("hemmelig") && !f.ord.contains("hemmelig") && !f.tilgjengeligTekst.contains("hemmelig"))
            #expect(!"\(f)".contains("hemmelig") && !String(reflecting: f).contains("hemmelig"))
        }
    }

    // MARK: - redigering

    @Test func tokenetLekkerAldriViaBeskrivelseEllerDump() throws {
        let t = try Tilkobling.fra(adresse: adresse, token: "hemmelig-0123456789abcdef0123")
        var dumpet = ""
        dump(t, to: &dumpet)
        for tekst in ["\(t)", "\(t.description)", String(reflecting: t), t.debugDescription, dumpet] {
            #expect(!tekst.contains("hemmelig"), "tokenet lekket i: \(tekst)")
        }
        #expect(t.description == "Tilkobling(ygg-v1.tail908368.ts.net)")
    }

    @Test func tilkoblingensKildeValgLekkerIkkeVedDump() throws {
        let t = try Tilkobling.fra(adresse: adresse, token: "hemmelig-0123456789abcdef0123")
        var dumpet = ""
        dump(t.kildeValg, to: &dumpet)
        #expect(!dumpet.contains("hemmelig") && !"\(t.kildeValg)".contains("hemmelig"))
    }

    @Test func minneLagerLekkerIkkeTokenet() throws {
        let t = try Tilkobling.fra(adresse: adresse, token: "hemmelig-0123456789abcdef0123")
        let l = MinneLager(t)
        var dumpet = ""
        dump(l, to: &dumpet)
        for tekst in ["\(l)", String(reflecting: l), dumpet] { #expect(!tekst.contains("hemmelig")) }
    }

    // MARK: - lagringsformat

    @Test func jsonRundtur() throws {
        let t = try Tilkobling.fra(adresse: adresse, token: token)
        let data = try t.json()
        let obj = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(obj == ["adresse": adresse, "token": token])
        #expect(try Tilkobling.fra(json: data) == t)
    }

    @Test func ødelagtEllerUgyldigJsonGirLagerfeilUtenInnhold() {
        for data in [Data("ikke json".utf8), Data("{}".utf8), Data(#"{"adresse":"http://x.example","token":"kort-hemmelig"}"#.utf8)] {
            do { _ = try Tilkobling.fra(json: data); Issue.record("skulle feilet") }
            catch { #expect(error as? LagerFeil == .ugyldigInnhold) }
        }
    }

    @Test func httpFraDebugLeses_barePåNyttNårTillatt() throws {
        let data = try Tilkobling(baseURL: URL(string: "http://localhost:3030")!, token: token).json()
        #expect(throws: LagerFeil.ugyldigInnhold) { try Tilkobling.fra(json: data) }
        #expect(try Tilkobling.fra(json: data, tillatHttpLoopback: true).vert == "localhost")
    }
}

@Suite struct BekreftTilkoblingTests {
    private let token = "tok-0123456789abcdef0123"

    private func tilkobling(_ stub: (session: URLSession, baseURL: URL, host: String)) -> Tilkobling {
        Tilkobling(baseURL: stub.baseURL, token: token)
    }

    private func fabrikk(_ session: URLSession) -> KlientFabrikk {
        { TraadflataKlient(baseURL: $0.baseURL, token: $0.token, session: session) }
    }

    private func utfall(_ stub: (session: URLSession, baseURL: URL, host: String)) async -> TilkoblingsFeil? {
        do { try await bekreftTilkobling(tilkobling(stub), klient: fabrikk(stub.session)); return nil }
        catch let f as TilkoblingsFeil { return f }
        catch { Issue.record("uventet feiltype \(type(of: error))"); return nil }
    }

    @Test func suksessKallerHentNaaMedTokenet() async throws {
        let stub = StubURLProtocol.oppsett { _ in StubSvar(status: 200, body: try Fixtur.data("naa.json")) }
        #expect(await utfall(stub) == nil)
        let r = try #require(StubURLProtocol.sett(host: stub.host).first)
        #expect(r.url?.path == "/api/naa")
        #expect(r.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)")
        #expect(StubURLProtocol.sett(host: stub.host).count == 1)
    }

    @Test func fireNullEnToGirIkkeInnlogget() async {
        let stub = StubURLProtocol.oppsett { _ in StubSvar(status: 401, body: Data("unauthorized".utf8)) }
        #expect(await utfall(stub) == .ikkeInnlogget)
    }

    @Test func nettverksfeilOgTidsavbruddGirIkkeNaabar() async {
        let av = StubURLProtocol.oppsett { _ in throw URLError(.notConnectedToInternet) }
        #expect(await utfall(av) == .ikkeNaabar)
        let tid = StubURLProtocol.oppsett { _ in throw URLError(.timedOut) }
        #expect(await utfall(tid) == .ikkeNaabar)
        let ukjentVert = StubURLProtocol.oppsett { _ in throw URLError(.cannotFindHost) }
        #expect(await utfall(ukjentVert) == .ikkeNaabar)
    }

    @Test func serverfeilGirTjenesteFeilMedStatusMenUtenSvartekst() async {
        let stub = StubURLProtocol.oppsett { _ in StubSvar(status: 503, body: Data(#"{"error":"hemmelig intern feil"}"#.utf8)) }
        let f = await utfall(stub)
        #expect(f == .tjenesteFeil(status: 503))
        #expect(f.map { !$0.melding.contains("hemmelig") } == true)
    }

    @Test func dekodingsfeilGirSvarIkkeForstaatt() async throws {
        // `Naa` er bevisst tolerant (`{}` er gyldig), så bare innhold som ikke er et objekt faller her.
        let liste = StubURLProtocol.oppsett { _ in StubSvar(status: 200, body: Data("[1,2]".utf8)) }
        #expect(await utfall(liste) == .svarIkkeForstaatt)
        let tom = StubURLProtocol.oppsett { _ in StubSvar(status: 200, body: Data("<html>login</html>".utf8)) }
        #expect(await utfall(tom) == .svarIkkeForstaatt)
    }

    @Test func tilkoblingsfeilFraTraadflatefeil() {
        #expect(TilkoblingsFeil.fra(.ikkeInnlogget) == .ikkeInnlogget)
        #expect(TilkoblingsFeil.fra(.nettverk("x")) == .ikkeNaabar)
        #expect(TilkoblingsFeil.fra(.http(status: 500, melding: "m")) == .tjenesteFeil(status: 500))
        #expect(TilkoblingsFeil.fra(.dekoding("d")) == .svarIkkeForstaatt)
        #expect(TilkoblingsFeil.fra(.ugyldigSvar) == .svarIkkeForstaatt)
    }

    @Test func standardFabrikkBrukerTilkoblingensAdresse() {
        let k = standardKlientFabrikk(Tilkobling(baseURL: URL(string: "https://x.example")!, token: token))
        #expect(k.baseURL.host == "x.example")
    }
}
