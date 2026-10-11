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

    @Test func argumenteneGjelderBareNårLiveErTillatt() {
        let args = ["--demo", "--auto-godkjenn", "--auto-svar=godkjenn", "--auto-bekreft", "--demo-svar=henger", "--demo-lang"]
        #expect(KildeValg.brukerAutoGodkjenn(argumenter: args, tillatLive: true))
        #expect(!KildeValg.brukerAutoGodkjenn(argumenter: args, tillatLive: false), "--auto-godkjenn har ingen virkning i release")
        #expect(KildeValg.autoSvar(argumenter: args, tillatLive: true) == .godkjenn)
        #expect(KildeValg.autoSvar(argumenter: args, tillatLive: false) == nil)
        #expect(KildeValg.brukerAutoBekreft(argumenter: args, tillatLive: true))
        #expect(!KildeValg.brukerAutoBekreft(argumenter: args, tillatLive: false))
        #expect(KildeValg.demoAvgjort(argumenter: args, tillatLive: true).atferd == .henger)
        #expect(KildeValg.demoAvgjort(argumenter: args, tillatLive: true).langtKort)
        #expect(KildeValg.demoAvgjort(argumenter: args, tillatLive: false).atferd == .avgjort)
        #expect(!KildeValg.demoAvgjort(argumenter: args, tillatLive: false).langtKort)
    }

    @Test func autoSvarKjennerBareGodkjennOgAvslaa() {
        #expect(KildeValg.autoSvar(argumenter: ["--auto-svar=avslaa"], tillatLive: true) == .avslaa)
        #expect(KildeValg.autoSvar(argumenter: ["--auto-svar=hva-som-helst"], tillatLive: true) == nil)
        #expect(KildeValg.autoSvar(argumenter: [], tillatLive: true) == nil)
    }

    @Test func tilgangForDemoSvarerLokaltOgDelerTilstandMedKilden() async throws {
        let demo = DemoAvgjort()
        let tilgang = KildeValg.demo(rolig: false).lagTilgang(demo: demo)
        #expect(try await tilgang.send("demo-alarm", "approve") == .avgjort)
        #expect(demo.erAvgjort("demo-alarm"))
    }
}
