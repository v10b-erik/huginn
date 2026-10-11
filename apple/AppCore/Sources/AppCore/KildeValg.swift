import Foundation

/// Hvilken kilde «Nå» skal bruke. Ren logikk, så regelen testes uten app: demo er standard, og live
/// kan bare velges der kallestedet uttrykkelig tillater det (DEBUG-bygg). Ingen Keychain, ingen innlogging ennå.
public enum KildeValg: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    case demo(rolig: Bool)
    case live(url: URL, token: String)

    public static let rolig = "--demo-rolig"
    public static let miljoURL = "HUGINN_URL"
    public static let miljoToken = "HUGINN_TOKEN"

    /// - Parameter tillatLive: `false` i release; da ignoreres miljøvariablene helt.
    public static func velg(argumenter: [String], miljo: [String: String], tillatLive: Bool) -> KildeValg {
        if tillatLive,
           let tekst = miljo[miljoURL], let url = URL(string: tekst), url.scheme?.hasPrefix("http") == true,
           let token = miljo[miljoToken], !token.isEmpty {
            return .live(url: url, token: token)
        }
        return .demo(rolig: argumenter.contains(rolig))
    }

    /// Kort navn til foten. Aldri tokenet.
    public var navn: String {
        switch self {
        case .demo(let rolig): rolig ? "demo · rolig" : "demo"
        case .live(let url, _): "live · \(url.host ?? "?")"
        }
    }

    /// Redigert: tokenet skal aldri havne i en logg.
    public var description: String { navn }
    public var debugDescription: String { navn }

    public var erDemo: Bool {
        if case .demo = self { return true }
        return false
    }

    public func lagKilde() -> any NaaKilde {
        switch self {
        case .demo(let rolig): DemoKilde(variant: rolig ? .rolig : .avvik)
        case .live(let url, let token): LiveKilde(klient: TraadflataKlient(baseURL: url, token: token))
        }
    }
}
