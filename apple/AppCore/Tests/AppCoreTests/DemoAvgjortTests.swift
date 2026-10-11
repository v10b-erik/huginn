import Foundation
import Testing
@testable import AppCore

@Suite struct DemoAvgjortTests {
    private let nå = Date(timeIntervalSince1970: 1_760_000_000)

    @Test func avgjortKortForsvinnerFraDemoskjermen() async throws {
        let demo = DemoAvgjort()
        let kilde = DemoKilde(variant: .avvik, nå: { Date(timeIntervalSince1970: 1_760_000_000) }, avgjort: demo)
        let før = try await kilde.hent()
        #expect(før.godkjenninger.map(\.id) == ["demo-alarm"])
        #expect(før.antallKrever == 1)
        #expect(try await demo.svar(kortId: "demo-alarm", key: "approve") == .avgjort)
        let etter = try await kilde.hent()
        #expect(etter.godkjenninger.isEmpty)
        #expect(etter.venter.isEmpty, "kortets «venter»-avvik forsvinner også, ellers telles saken som en ny")
        #expect(etter.tilstand == .rolig)
    }

    @Test func utenDemoAvgjortErSkjermenUendret() async throws {
        let a = try await DemoKilde(variant: .avvik, nå: { Date(timeIntervalSince1970: 1_760_000_000) }).hent()
        let b = try await DemoKilde(variant: .avvik, nå: { Date(timeIntervalSince1970: 1_760_000_000) }, avgjort: DemoAvgjort()).hent()
        #expect(a == b)
    }

    @Test func langtKortGirHelTekstOgFortsattEttKort() async throws {
        let kilde = DemoKilde(variant: .avvik, nå: { Date(timeIntervalSince1970: 1_760_000_000) }, avgjort: DemoAvgjort(langtKort: true))
        let s = try await kilde.hent()
        #expect(s.godkjenninger.count == 1)
        #expect(s.godkjenninger[0].tittel.contains("\n"))
        #expect(s.godkjenninger[0].tittel.count > 500)
        #expect(s.venter.isEmpty, "«venter»-avviket matcher kortets første linje og telles ikke dobbelt")
        #expect(s.antallKrever == 1)
    }

    @Test func demoKortetFårHandlingeneSomErBedt() async throws {
        func skjerm(_ h: DemoAvgjort.Handlinger) async throws -> NaaSkjerm {
            try await DemoKilde(variant: .avvik, nå: { Date(timeIntervalSince1970: 1_760_000_000) }, avgjort: DemoAvgjort(handlinger: h)).hent()
        }
        #expect(try await skjerm(.standard).godkjenninger[0].godkjenn?.label == "Godkjenn")
        #expect(try await skjerm(.en).godkjenninger[0].godkjenn?.label == "✉️ Send")
        #expect(try await skjerm(.flere).godkjenninger[0].godkjenn == nil)
    }

    @Test func atferdeneSimulererServeren() async throws {
        #expect(try await DemoAvgjort(atferd: .alleredeAvgjort).svar(kortId: "demo-alarm", key: "deny") == .alleredeAvgjort("kortet er allerede avgjort"))
        await #expect(throws: TraadflataFeil.nettverk("demo")) {
            try await DemoAvgjort(atferd: .usikkert).svar(kortId: "demo-alarm", key: "approve")
        }
        await #expect(throws: TraadflataFeil.ugyldigKortId) {
            try await DemoAvgjort().svar(kortId: "x", key: "approve")
        }
    }

    // MARK: - launch-argumenter (bare DEBUG)

    private let demo = KildeValg.demo(rolig: false)
    private let live = KildeValg.live(url: URL(string: "https://eksempel.example.com")!, token: "tok-0123456789abcdef01234567")

    @Test func argumenteneGjelderBareNårLiveErTillatt() {
        let args = ["--demo", "--auto-godkjenn", "--auto-svar=godkjenn", "--auto-bekreft", "--demo-svar=henger", "--demo-lang", "--demo-handlinger=flere"]
        #expect(KildeValg.brukerAutoGodkjenn(argumenter: args, tillatLive: true, valg: demo))
        #expect(!KildeValg.brukerAutoGodkjenn(argumenter: args, tillatLive: false, valg: demo), "--auto-godkjenn har ingen virkning i release")
        #expect(KildeValg.autoSvar(argumenter: args, tillatLive: true, valg: demo) == .godkjenn)
        #expect(KildeValg.autoSvar(argumenter: args, tillatLive: false, valg: demo) == nil)
        #expect(KildeValg.brukerAutoBekreft(argumenter: args, tillatLive: true, valg: demo))
        #expect(!KildeValg.brukerAutoBekreft(argumenter: args, tillatLive: false, valg: demo))
        #expect(KildeValg.demoAvgjort(argumenter: args, tillatLive: true).atferd == .henger)
        #expect(KildeValg.demoAvgjort(argumenter: args, tillatLive: true).langtKort)
        #expect(KildeValg.demoAvgjort(argumenter: args, tillatLive: true).handlinger == .flere)
        #expect(KildeValg.demoAvgjort(argumenter: args, tillatLive: false).atferd == .avgjort)
        #expect(!KildeValg.demoAvgjort(argumenter: args, tillatLive: false).langtKort)
        #expect(KildeValg.demoAvgjort(argumenter: args, tillatLive: false).handlinger == .standard)
    }

    /// R1: mot en live kilde har ingen auto-oppførsel virkning, selv i DEBUG og med alle argumentene.
    @Test func autoOppførselHarIngenVirkningMotLiveKilde() {
        let args = ["--auto-godkjenn", "--auto-svar=godkjenn", "--auto-svar=avslaa", "--auto-bekreft"]
        #expect(!KildeValg.brukerAutoGodkjenn(argumenter: args, tillatLive: true, valg: live))
        #expect(KildeValg.autoSvar(argumenter: args, tillatLive: true, valg: live) == nil)
        #expect(!KildeValg.brukerAutoBekreft(argumenter: args, tillatLive: true, valg: live))
    }

    @Test func autoSvarKjennerBareGodkjennOgAvslaa() {
        #expect(KildeValg.autoSvar(argumenter: ["--auto-svar=avslaa"], tillatLive: true, valg: demo) == .avslaa)
        #expect(KildeValg.autoSvar(argumenter: ["--auto-svar=hva-som-helst"], tillatLive: true, valg: demo) == nil)
        #expect(KildeValg.autoSvar(argumenter: [], tillatLive: true, valg: demo) == nil)
    }

    @Test func tilgangForDemoSvarerLokaltOgDelerTilstandMedKilden() async throws {
        let demo = DemoAvgjort()
        let tilgang = KildeValg.demo(rolig: false).lagTilgang(demo: demo)
        #expect(try await tilgang.send("demo-alarm", "approve") == .avgjort)
        #expect(demo.erAvgjort("demo-alarm"))
    }
}
