import Foundation

/// Hvilken kilde «Nå» skal bruke. Ren logikk, så regelen testes uten app. Miljøvariablene gjelder bare der
/// kallestedet uttrykkelig tillater det (DEBUG-bygg); den lagrede tilkoblingen leses av `Innlogging`.
public enum KildeValg: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    /// `ekte`: demoen med ekte FORM (lange, maskinaktige strenger), men syntetisk innhold. Bare i DEBUG (`--demo-ekte`).
    case demo(rolig: Bool, ekte: Bool = false)
    case live(url: URL, token: String)

    public static let demo = "--demo"
    public static let rolig = "--demo-rolig"
    public static let ekte = "--demo-ekte"
    public static let miljoURL = "HUGINN_URL"
    public static let miljoToken = "HUGINN_TOKEN"

    /// Presedens: launch-argument `--demo`/`--demo-rolig` > DEBUG-miljø (`HUGINN_URL` + `HUGINN_TOKEN`) > lagret
    /// tilkobling > ingen kilde (`nil`: da skal «Koble til» vises). Demo er aldri en stille reserve.
    /// - Parameter tillatLive: `false` i release; da ignoreres miljøvariablene helt.
    /// `--demo-ekte` er et synsløkke-verktøy og følger `tillatLive`: i release ignoreres det.
    public static func velg(argumenter: [String], miljo: [String: String], tillatLive: Bool, lagret: Tilkobling? = nil) -> KildeValg? {
        if tillatLive, argumenter.contains(ekte) { return .demo(rolig: false, ekte: true) }
        if argumenter.contains(rolig) { return .demo(rolig: true) }
        if argumenter.contains(demo) { return .demo(rolig: false) }
        if tillatLive,
           let tekst = miljo[miljoURL], let url = URL(string: tekst), url.scheme?.hasPrefix("http") == true,
           let token = miljo[miljoToken], !token.isEmpty {
            return .live(url: url, token: token)
        }
        return lagret?.kildeValg
    }

    /// Kort navn til foten. Aldri tokenet.
    public var navn: String {
        switch self {
        case .demo(let rolig, let ekte): ekte ? "demo · ekte" : (rolig ? "demo · rolig" : "demo")
        case .live(let url, _): "live · \(vertVisning(url.host))"
        }
    }

    /// Redigert: tokenet skal aldri havne i en logg.
    public var description: String { navn }
    public var debugDescription: String { navn }
    public var customMirror: Mirror { Mirror(self, children: ["kilde": navn]) }

    public var erDemo: Bool {
        if case .demo = self { return true }
        return false
    }

    public func lagKilde() -> any NaaKilde {
        switch self {
        case .demo(let rolig, let ekte): DemoKilde(variant: ekte ? .ekte : (rolig ? .rolig : .avvik))
        case .live(let url, let token): LiveKilde(klient: TraadflataKlient(baseURL: url, token: token))
        }
    }
}
