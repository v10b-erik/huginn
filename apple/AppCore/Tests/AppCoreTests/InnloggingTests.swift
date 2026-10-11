import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import AppCore

@Suite struct InnloggingTests {
    private let token = "tok-0123456789abcdef0123"
    private let adresse = "https://ygg.example:8444"
    private var lagretT: Tilkobling { Tilkobling(baseURL: URL(string: "https://lagret.example")!, token: "lagret-hemmelig-0123456789") }

    private func ny(_ lager: MinneLager = MinneLager(), loopback: Bool = false) -> Innlogging {
        Innlogging(lager: lager, tillatHttpLoopback: loopback)
    }

    private func startet(_ lager: MinneLager = MinneLager(), argumenter: [String] = [], miljo: [String: String] = [:], tillatLive: Bool = false) -> Innlogging {
        var i = ny(lager)
        i.start(argumenter: argumenter, miljo: miljo, tillatLive: tillatLive)
        return i
    }

    private func kobleKrev(_ i: inout Innlogging, adresse: String, token: String) throws -> Tilkobling {
        guard let t = i.koble(adresse: adresse, token: token) else { throw TilkoblingsFeil.adresseUgyldig }
        return t
    }

    // MARK: - start

    @Test func begynnerISpinner() {
        #expect(ny().tilstand == .laster)
    }

    @Test func tomtLagerGirIkkeKoblet() {
        #expect(startet().tilstand == .ikkeKoblet(feil: nil))
    }

    @Test func lagretTilkoblingGirKoblet() {
        let i = startet(MinneLager(lagretT))
        #expect(i.tilstand == .koblet(lagretT))
        #expect(i.lagret == lagretT)
    }

    @Test func demoArgumentSlårLagret() {
        #expect(startet(MinneLager(lagretT), argumenter: ["--demo"]).tilstand == .demo(rolig: false))
        #expect(startet(MinneLager(lagretT), argumenter: ["--demo-rolig"]).tilstand == .demo(rolig: true))
    }

    @Test func miljøSlårLagretBareNårTillatt() {
        let miljo = ["HUGINN_URL": "https://env.example", "HUGINN_TOKEN": "env-token"]
        if case .koblet(let t) = startet(MinneLager(lagretT), miljo: miljo, tillatLive: true).tilstand {
            #expect(t.vert == "env.example")
        } else { Issue.record("forventet koblet via miljø") }
        #expect(startet(MinneLager(lagretT), miljo: miljo, tillatLive: false).tilstand == .koblet(lagretT))
        #expect(startet(MinneLager(), miljo: miljo, tillatLive: false).tilstand == .ikkeKoblet(feil: nil))
    }

    @Test func leseFeilGirIkkeKobletMedFeilOgIngenKildeFraLageret() {
        let l = MinneLager(lagretT)
        l.feilVed(.les, .keychain(status: -25308))
        let i = startet(l)
        #expect(i.tilstand == .ikkeKoblet(feil: .kunneIkkeLese))
        #expect(i.lagret == nil)
        #expect(l.antallSkrivinger == 0)
    }

    @Test func leseFeilStopperIkkeDemoArgument() {
        let l = MinneLager(lagretT)
        l.feilVed(.les, .keychain(status: -1))
        #expect(startet(l, argumenter: ["--demo"]).tilstand == .demo(rolig: false))
    }

    // MARK: - koble

    @Test func gyldigInndataGirKoblerOgTilkoblingenSomSkalBekreftes() {
        let l = MinneLager()
        var i = startet(l)
        let t = i.koble(adresse: " \(adresse)/ ", token: token)
        #expect(i.tilstand == .kobler)
        #expect(t?.adresse == adresse)
        #expect(t?.token == token)
        #expect(l.antallSkrivinger == 0, "ingenting lagres før bekreftelsen")
        #expect(l.innhold == nil)
    }

    @Test func ugyldigInndataGirFeilOgRørerIkkeLageret() {
        let l = MinneLager(lagretT)
        var i = startet(l)
        i.visKobling()
        #expect(i.koble(adresse: adresse, token: "kort") == nil)
        #expect(i.tilstand == .ikkeKoblet(feil: .tokenForKort))
        #expect(i.koble(adresse: "http://x.example", token: token) == nil)
        #expect(i.tilstand == .ikkeKoblet(feil: .adresseIkkeHttps))
        #expect(l.innhold == lagretT)
        #expect(l.antallSkrivinger == 0)
    }

    @Test func httpLoopbackBareMedTillatelse() {
        var release = ny(); release.start(argumenter: [], miljo: [:], tillatLive: false)
        #expect(release.koble(adresse: "http://localhost:3030", token: token) == nil)
        var debug = ny(loopback: true); debug.start(argumenter: [], miljo: [:], tillatLive: true)
        #expect(debug.koble(adresse: "http://localhost:3030", token: token) != nil)
    }

    @Test func kobleIgnoreresUtenomIkkeKoblet() {
        var i = startet(MinneLager(lagretT))
        #expect(i.koble(adresse: adresse, token: token) == nil)
        #expect(i.tilstand == .koblet(lagretT), "koblet må åpnes med visKobling først")
        var l = ny()
        #expect(l.koble(adresse: adresse, token: token) == nil)
        #expect(l.tilstand == .laster)
    }

    // MARK: - bekreftet / feilet

    @Test func kobletOkLagrerOgGårTilKoblet() throws {
        let l = MinneLager()
        var i = startet(l)
        let t = try kobleKrev(&i, adresse: adresse, token: token)
        i.kobletOk(t)
        #expect(i.tilstand == .koblet(t))
        #expect(l.innhold == t)
        #expect(i.lagret == t)
    }

    @Test func feilUnderKoblerGårTilbakeMedFeilenOgRørerIkkeLageret() throws {
        for feil: TilkoblingsFeil in [.ikkeInnlogget, .ikkeNaabar, .tjenesteFeil(status: 502), .svarIkkeForstaatt] {
            let l = MinneLager()
            var i = startet(l)
            _ = try kobleKrev(&i, adresse: adresse, token: token)
            i.kobletFeilet(feil)
            #expect(i.tilstand == .ikkeKoblet(feil: feil))
            #expect(l.innhold == nil)
            #expect(l.antallSkrivinger == 0)
        }
    }

    @Test func mislykketForsøkEndrerIkkeDetSomAlleredeErLagret() throws {
        let l = MinneLager(lagretT)
        var i = startet(l)
        i.visKobling()
        _ = try kobleKrev(&i, adresse: adresse, token: token)
        i.kobletFeilet(.ikkeInnlogget)
        #expect(l.innhold == lagretT)
        #expect(i.lagret == lagretT)
        #expect(l.antallSkrivinger == 0)
    }

    @Test func skriveFeilEtterBekreftelseGirIkkeKobletOgLeggerIngenHalvveisTilkobling() throws {
        let l = MinneLager(lagretT)
        l.feilVed(.lagre, .keychain(status: -34018))
        var i = startet(l)
        i.visKobling()
        let t = try kobleKrev(&i, adresse: adresse, token: token)
        i.kobletOk(t)
        #expect(i.tilstand == .ikkeKoblet(feil: .kunneIkkeLagre))
        #expect(l.innhold == lagretT, "det gamle er urørt")
        #expect(i.lagret == lagretT)
    }

    @Test func kobletOkOgKobletFeiletIgnoreresUtenomKobler() {
        var i = startet(MinneLager(lagretT))
        i.kobletOk(Tilkobling(baseURL: URL(string: "https://annen.example")!, token: token))
        #expect(i.tilstand == .koblet(lagretT))
        i.kobletFeilet(.ikkeNaabar)
        #expect(i.tilstand == .koblet(lagretT))
    }

    @Test func avbruddUnderKoblerGirSkjemaUtenFeilOgRørerIkkeLageret() throws {
        let l = MinneLager(lagretT)
        var i = startet(l)
        i.visKobling()
        _ = try kobleKrev(&i, adresse: adresse, token: token)
        i.avbrytKobler()
        #expect(i.tilstand == .ikkeKoblet(feil: nil), "avbrudd er ikke en feil")
        #expect(i.kanAvbryte, "veien tilbake til det lagrede er der fortsatt")
        #expect(l.innhold == lagretT && l.antallSkrivinger == 0)
        // Et sent «ok» fra det avbrutte forsøket skal ikke kunne lagre noe.
        i.kobletOk(Tilkobling(baseURL: URL(string: "https://sen.example")!, token: token))
        #expect(i.tilstand == .ikkeKoblet(feil: nil))
        #expect(l.innhold == lagretT)
    }

    @Test func avbrytKoblerGjelderBareUnderKobler() {
        var i = startet(MinneLager(lagretT))
        i.avbrytKobler()
        #expect(i.tilstand == .koblet(lagretT))
    }

    // MARK: - koble fra

    @Test func kobleFraSletterFraLageret() {
        let l = MinneLager(lagretT)
        var i = startet(l)
        i.kobleFra()
        #expect(i.tilstand == .ikkeKoblet(feil: nil))
        #expect(l.innhold == nil)
        #expect(i.lagret == nil)
        #expect(startet(l).tilstand == .ikkeKoblet(feil: nil), "neste oppstart er også ukoblet")
    }

    @Test func kobleFraSomFeilerBlirKobletOgSierFra() {
        let l = MinneLager(lagretT)
        l.feilVed(.slett, .keychain(status: -1))
        var i = startet(l)
        i.kobleFra()
        #expect(i.tilstand == .koblet(lagretT))
        #expect(i.handlingsFeil == .kunneIkkeSlette)
        #expect(l.innhold == lagretT)
    }

    @Test func kobleFraGjelderBareNårKoblet() {
        let l = MinneLager(lagretT)
        var i = startet(l, argumenter: ["--demo"])
        i.kobleFra()
        #expect(i.tilstand == .demo(rolig: false))
        #expect(l.innhold == lagretT, "demo-økten sletter ikke det lagrede")
    }

    // MARK: - demo, vis kobling, avbryt

    @Test func prøvDemoFraIkkeKobletRørerIkkeLageret() {
        let l = MinneLager()
        var i = startet(l)
        i.prøvDemo()
        #expect(i.tilstand == .demo(rolig: false))
        i.prøvDemo(rolig: true)
        #expect(i.tilstand == .demo(rolig: true))
        #expect(l.antallSkrivinger == 0)
    }

    @Test func byttTilDemoFraKobletBeholderLageret() {
        let l = MinneLager(lagretT)
        var i = startet(l)
        i.prøvDemo()
        #expect(i.tilstand == .demo(rolig: false))
        #expect(l.innhold == lagretT)
        #expect(startet(l).tilstand == .koblet(lagretT), "demo gjelder økten, ikke neste oppstart")
    }

    @Test func prøvDemoIgnoreresMensDetKobles() throws {
        var i = startet()
        _ = try kobleKrev(&i, adresse: adresse, token: token)
        i.prøvDemo()
        #expect(i.tilstand == .kobler)
    }

    @Test func visKoblingFraKobletBeholderLagretOgAvbrytGårTilbake() {
        let l = MinneLager(lagretT)
        var i = startet(l)
        #expect(!i.kanAvbryte)
        i.visKobling()
        #expect(i.tilstand == .ikkeKoblet(feil: nil))
        #expect(i.kanAvbryte)
        #expect(l.innhold == lagretT)
        i.avbryt()
        #expect(i.tilstand == .koblet(lagretT))
        #expect(!i.kanAvbryte)
    }

    @Test func avbrytFraDemoGårTilbakeTilDemo() {
        var i = startet(argumenter: ["--demo-rolig"])
        i.visKobling()
        #expect(i.kanAvbryte)
        i.avbryt()
        #expect(i.tilstand == .demo(rolig: true))
    }

    @Test func førsteGangKanManIkkeAvbryte() {
        var i = startet()
        #expect(!i.kanAvbryte)
        i.avbryt()
        #expect(i.tilstand == .ikkeKoblet(feil: nil))
    }

    @Test func nyTilkobling_etterVisKobling_erstatterDetLagrede() throws {
        let l = MinneLager(lagretT)
        var i = startet(l)
        i.visKobling()
        let t = try kobleKrev(&i, adresse: adresse, token: token)
        i.kobletOk(t)
        #expect(i.tilstand == .koblet(t))
        #expect(l.innhold == t)
        #expect(!i.kanAvbryte)
    }

    @Test func brukLagretFraDemoGirKoblet() {
        let l = MinneLager(lagretT)
        var i = startet(l, argumenter: ["--demo"])
        #expect(i.lagret == lagretT)
        i.brukLagret()
        #expect(i.tilstand == .koblet(lagretT))
        var tom = startet(MinneLager(), argumenter: ["--demo"])
        tom.brukLagret()
        #expect(tom.tilstand == .demo(rolig: false))
    }

    // MARK: - ende til ende med bekreftelse

    @Test func heleVeienMedStubbetServer() async throws {
        let l = MinneLager()
        var i = startet(l)
        let stub = StubURLProtocol.oppsett { r in
            r.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)"
                ? StubSvar(status: 200, body: try Fixtur.data("naa.json"))
                : StubSvar(status: 401, body: Data())
        }
        // Feil token først.
        var t = try kobleKrev(&i, adresse: stub.baseURL.absoluteString, token: "feil-token-0123456789abcdef")
        do {
            try await bekreftTilkobling(t) { TraadflataKlient(baseURL: $0.baseURL, token: $0.token, session: stub.session) }
            i.kobletOk(t)
        } catch let f as TilkoblingsFeil { i.kobletFeilet(f) }
        #expect(i.tilstand == .ikkeKoblet(feil: .ikkeInnlogget))
        #expect(l.innhold == nil)
        // Så riktig token.
        t = try kobleKrev(&i, adresse: stub.baseURL.absoluteString, token: token)
        try await bekreftTilkobling(t) { TraadflataKlient(baseURL: $0.baseURL, token: $0.token, session: stub.session) }
        i.kobletOk(t)
        #expect(i.tilstand == .koblet(t))
        #expect(l.innhold == t)
    }

    // MARK: - lekkasje

    @Test func ingenTilstandEllerLagerLekkerTokenet() {
        let t = Tilkobling(baseURL: URL(string: "https://x.example")!, token: "hemmelig-0123456789abcdef0123")
        let tilstander: [Innlogging.Tilstand] = [.laster, .ikkeKoblet(feil: .ikkeInnlogget), .kobler, .koblet(t), .demo(rolig: true)]
        for s in tilstander {
            var dumpet = ""
            dump(s, to: &dumpet)
            for tekst in ["\(s)", String(reflecting: s), dumpet] { #expect(!tekst.contains("hemmelig"), "lekket i \(tekst)") }
        }
        var i = Innlogging(lager: MinneLager(t))
        i.start(argumenter: [], miljo: [:], tillatLive: false)
        var dumpet = ""
        dump(i, to: &dumpet)
        for tekst in ["\(i)", String(reflecting: i), dumpet] { #expect(!tekst.contains("hemmelig"), "lekket i \(tekst)") }
    }
}
