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
    /// `--demo-vert=<host>` (synsløkka, bare DEBUG): demoens kilde-linje vises som `live · <første ledd av host>`,
    /// så foten kan fotograferes i formen som brakk (`live · ygg-v1`) uten ekte tilkobling.
    public static let demoVertPrefiks = "--demo-vert="
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
        case .demo(let rolig, let ekte): ekte ? "demo · ekte form" : (rolig ? "demo · rolig" : "demo")
        case .live(let url, _): "live · \(vertVisning(url.host))"
        }
    }

    /// Verten fra `--demo-vert=`, eller `nil` (ikke gitt, tom, eller `tillatLive == false`, som i release).
    public static func demoVert(argumenter: [String], tillatLive: Bool) -> String? {
        guard tillatLive,
              let a = argumenter.first(where: { $0.hasPrefix(demoVertPrefiks) }) else { return nil }
        let v = String(a.dropFirst(demoVertPrefiks.count))
        return v.isEmpty ? nil : v
    }

    /// Kilde-linja i foten: full og smal form. For en demo med `demoVert` ser den ut som en live-kilde.
    public func fot(demoVert: String?) -> (full: String, smal: String) {
        if erDemo, let demoVert {
            let vert = vertVisning(demoVert)
            return ("live · \(vert)", vert)
        }
        return (navn, smaltNavn)
    }

    /// Foten når «live · ygg-v1» ikke får plass: bare det som skiller (verten). Demo har ingenting å korte inn.
    public var smaltNavn: String {
        switch self {
        case .demo: navn
        case .live(let url, _): vertVisning(url.host)
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

    /// `--demo-svar=<avgjort|henger|usikkert|alleredeAvgjort>` og `--demo-lang` (synsløkka, bare DEBUG): hva demoens
    /// lokale «server» svarer på Godkjenn/Avslå, og om kortet har en lang tekst. Utenfor DEBUG (`tillatLive == false`)
    /// alltid standard.
    public static let demoSvarPrefiks = "--demo-svar="
    public static let demoLang = "--demo-lang"
    /// `--demo-handlinger=<en|flere>`: demokortet har én egen handling («✉️ Send») eller to (ingen Godkjenn-vei).
    public static let demoHandlingerPrefiks = "--demo-handlinger="
    /// `--auto-godkjenn` (synsløkka, bare DEBUG): erstatter lokal autentisering med en som alltid lykkes, så flyten kan
    /// kjøres på simulator uten biometri. Skal aldri ha noen virkning i release.
    public static let autoGodkjenn = "--auto-godkjenn"
    /// `--auto-svar=<godkjenn|avslaa>` (synsløkka, bare DEBUG): åpner bekreftelsen for første kort ved start.
    public static let autoSvarPrefiks = "--auto-svar="
    /// `--auto-bekreft` (synsløkka, bare DEBUG): trykker bekreft i bekreftelsen som `--auto-svar` åpnet.
    public static let autoBekreft = "--auto-bekreft"

    public static func demoAvgjort(argumenter: [String], tillatLive: Bool) -> DemoAvgjort {
        guard tillatLive else { return DemoAvgjort() }
        let atferd = argumenter.first { $0.hasPrefix(demoSvarPrefiks) }
            .flatMap { DemoAvgjort.Atferd(rawValue: String($0.dropFirst(demoSvarPrefiks.count))) } ?? .avgjort
        let handlinger = argumenter.first { $0.hasPrefix(demoHandlingerPrefiks) }
            .flatMap { DemoAvgjort.Handlinger(rawValue: String($0.dropFirst(demoHandlingerPrefiks.count))) } ?? .standard
        return DemoAvgjort(atferd: atferd, langtKort: argumenter.contains(demoLang), handlinger: handlinger)
    }

    /// Bare for en DEMO-kilde: mot en live kilde har ingen auto-oppførsel noen virkning, uansett argumenter. Ellers kunne et
    /// glemt argument (eller en agent som styrer UI) godkjent et ekte kort uten biometri.
    public static func brukerAutoGodkjenn(argumenter: [String], tillatLive: Bool, valg: KildeValg) -> Bool {
        tillatLive && valg.erDemo && argumenter.contains(autoGodkjenn)
    }

    /// `godkjenn` eller `avslaa`, eller `nil`.
    public static func autoSvar(argumenter: [String], tillatLive: Bool, valg: KildeValg) -> NaaSkjerm.Handling.Valg? {
        guard tillatLive, valg.erDemo, let a = argumenter.first(where: { $0.hasPrefix(autoSvarPrefiks) }) else { return nil }
        switch a.dropFirst(autoSvarPrefiks.count) {
        case "godkjenn": return .godkjenn
        case "avslaa": return .avslaa
        default: return nil
        }
    }

    public static func brukerAutoBekreft(argumenter: [String], tillatLive: Bool, valg: KildeValg) -> Bool {
        tillatLive && valg.erDemo && argumenter.contains(autoBekreft)
    }

    /// Kilden og skriveveien til «Nå», bygget sammen så de deler tilstand (demo: hva som er avgjort).
    public struct Tilgang: Sendable {
        public var kilde: any NaaKilde
        public var send: SvarTjeneste.Send
    }

    public func lagTilgang(demo: DemoAvgjort = DemoAvgjort()) -> Tilgang {
        switch self {
        case .demo(let rolig, let ekte):
            return Tilgang(
                kilde: DemoKilde(variant: ekte ? .ekte : (rolig ? .rolig : .avvik), avgjort: demo),
                send: { try await demo.svar(kortId: $0, key: $1) }
            )
        case .live(let url, let token):
            let klient = TraadflataKlient(baseURL: url, token: token)
            return Tilgang(kilde: LiveKilde(klient: klient), send: { try await klient.svar(kortId: $0, key: $1) })
        }
    }

    public func lagKilde() -> any NaaKilde {
        switch self {
        case .demo(let rolig, let ekte): DemoKilde(variant: ekte ? .ekte : (rolig ? .rolig : .avvik))
        case .live(let url, let token): LiveKilde(klient: TraadflataKlient(baseURL: url, token: token))
        }
    }
}
