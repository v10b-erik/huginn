import Foundation

/// Visningsmodellen for «Tråder»: en lesevisning over det `GET /api/traader` faktisk gir. Bygges deterministisk av
/// `[Traad]` + en injisert `nå` (ingenting her leser klokka). Radene er `NaaSkjerm.Rad`, så de tegnes av samme
/// listerad som «Nå» og følger de samme reglene (tilstand alltid som ORD, aldri farge alene; regel 4).
///
/// Felt som brukes: `id`, `tittel`, `sistAktiv`, `arkivert`, `holder.{type,status,aktiv}`, `live.opptatt`,
/// `prosjekt.label`, `ko`. Ingenting annet leses, og ingenting oppdiktes.
public struct TraadSkjerm: Sendable, Equatable {
    /// Serverens standardtak (`verdandi.list`, `limit ?? 50`): får vi så mange, kan listen være avkortet.
    public static let serverGrense = 50
    /// Standardvinduet serveren bruker uten `dager` (30 døgn).
    public static let tomTekstVanlig = "Ingen tråder de siste 30 dagene"

    /// Vinduet serveren bruker (døgn). Står i toppetiketten («TRÅDER · 30 D») og forklarer overskriftstallet.
    public static let vinduDager = 30
    /// Etter så mange sekunder er en liste gammel nok til at den hentes på nytt når fanen blir synlig igjen.
    public static let friskhetSekunder: TimeInterval = 60

    /// Tråder som VENTER (`blocked`, ikke arkivert): festes øverst. Nyeste først, med `id` som avgjører ved lik tid.
    public var venter: [NaaSkjerm.Rad]
    /// Resten, nyeste først.
    public var ovrige: [NaaSkjerm.Rad]

    /// Alle rader i visningsrekkefølge: de som venter først.
    public var rader: [NaaSkjerm.Rad] { venter + ovrige }
    public var antall: Int { rader.count }
    public var tomTekst: String { Self.tomTekstVanlig }
    public var kanVæreAvkortet: Bool { antall >= Self.serverGrense }

    /// Overskriftstallet med enhet og vindu: «6 tråder · 30 d» («30 d» når antallet er ukjent).
    public var antallTekst: String { Self.antallTekst(antall) }
    public static func antallTekst(_ n: Int?) -> String {
        guard let n else { return "\(vinduDager) d" }  // ukjent antall: bare vinduet
        return "\(n) \(n == 1 ? "tråd" : "tråder") · \(vinduDager) d"
    }
    /// Toppetiketten, mono og versalt (viewet versaliserer). Vinduet («30 D») står bare i kortets tall.
    public static let toppEtikett = "Tråder"

    /// Statusboksen øverst til høyre: hva som krever deg, ellers at alt er rolig.
    public var statusTekst: String { venter.isEmpty ? "Alt rolig" : "\(venter.count) venter" }

    /// Er en liste hentet `sist` for gammel til å stå (brukes når fanen blir synlig)? Ingen henting ennå = gammel.
    public static func erGammel(sistHentet sist: Date?, nå: Date) -> Bool {
        guard let sist else { return true }
        return nå.timeIntervalSince(sist) > friskhetSekunder
    }

    public init(traader: [Traad], nå: Date) {
        let sortert = traader.sorted { ($0.sistAktiv, $1.id) > ($1.sistAktiv, $0.id) }
        venter = sortert.filter { Self.venter($0) }.map { Self.rad($0, nå: nå) }
        ovrige = sortert.filter { !Self.venter($0) }.map { Self.rad($0, nå: nå) }
    }

    /// En arkivert tråd venter aldri, selv om holderen sto blokkert da den ble arkivert (samme rekkefølge som `tilstand`).
    static func venter(_ t: Traad) -> Bool { tilstand(t).ord == "VENTER" }

    /// Tilstanden som ord og tone. Samme lesing som «Nå» gjør av holderen: `working`/opptatt = pågår,
    /// `blocked` = står stille og venter, en aktiv holder uten arbeid = åpen, ellers parkert. Arkivert slår alt.
    ///
    /// MERK: Tråder ser IKKE kortkoblingen. «Nå» regner en tråd som venter også når et ventende kort har trådens
    /// `threadKey` (Telegram-nøkkel eller oppgavenøkkel); her finnes bare `holder.status == blocked`. En tråd kan
    /// derfor stå som VENTER på «Nå» og som PÅGÅR/ÅPEN her. Å lukke gapet krever kortene inn i Tråder-kilden, og
    /// det er ikke gjort. `blocked` og `opptatt` samtidig gir VENTER (en blokkert tråd venter på deg, selv om den
    /// er opptatt).
    static func tilstand(_ t: Traad) -> (ord: String, tone: NaaSkjerm.Tone) {
        if t.arkivert != nil { return ("ARKIVERT", .dempet) }
        let status = t.holder?.status?.lowercased()
        if status == "blocked" { return ("VENTER", .aksent) }
        if t.live?.opptatt == true || status == "working" { return ("PÅGÅR", .aksent) }
        if t.holder?.aktiv == true { return ("ÅPEN", .dempet) }
        return ("PARKERT", .dempet)
    }

    private static func holdertekst(_ t: Traad) -> String? {
        guard let h = t.holder, h.aktiv else { return nil }
        switch h.type {
        case .terminal: return "terminal"
        case .plattform: return "plattform"
        case .ukjent(let v): return v.isEmpty ? nil : v
        }
    }

    private static func rad(_ t: Traad, nå: Date) -> NaaSkjerm.Rad {
        let (ord, tone) = tilstand(t)
        let prosjekt = t.prosjekt?.label.flatMap { $0.isEmpty ? nil : $0 }
        let holder = holdertekst(t)
        // Holderen står bare i VoiceOver-teksten: en tredje del i undertekstlinja brøt i to linjer på smal skjerm.
        // «N i kø» står på en EGEN linje (ikke etter en «·»): en linjebrytning kan da aldri starte en linje med prikken,
        // og «N i kø» er udelelig (hardt mellomrom).
        let ko = (t.ko ?? 0) > 0 ? "\(t.ko!)\u{00A0}i\u{00A0}kø" : nil
        let tale = ([t.tittel, ord.lowercased()] + [holder, ko.map { $0.replacingOccurrences(of: "\u{00A0}", with: " ") }].compactMap { $0 }
            + ["sist aktiv " + Tid.relativTalt(fra: t.sistAktiv, til: nå)]).joined(separator: ", ")
        return NaaSkjerm.Rad(
            id: t.id, tittel: t.tittel, undertekst: prosjekt,
            ord: ord, tid: Tid.relativ(fra: t.sistAktiv, til: nå), tone: tone, undertekstLinjer: 1, tale: tale,
            pågår: ord == "PÅGÅR", tittelLinjer: 1, tillegg: ko, brytFritt: true
        )
    }
}

/// Hvor «Tråder» henter innholdet fra. Viewet kjenner bare dette; demo og live byttes i `KildeValg`.
public protocol TraadKilde: Sendable {
    func hent() async throws -> TraadSkjerm
}

/// Ekte data: `GET /api/traader` med enhetstokenet i klienten. Feil kastes videre (aldri en stille reserve).
public struct LiveTraadKilde: TraadKilde, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    private let klient: TraadflataKlient
    private let nå: @Sendable () -> Date

    public init(klient: TraadflataKlient, nå: @escaping @Sendable () -> Date = { Date() }) {
        self.klient = klient
        self.nå = nå
    }

    public var description: String { "LiveTraadKilde(\(klient.baseURL.host ?? "?"))" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: ["baseURL": klient.baseURL]) }

    public func hent() async throws -> TraadSkjerm {
        TraadSkjerm(traader: try await klient.hentTraader(), nå: nå())
    }
}

/// Demoen: SYNTETISKE tråder («eksempel»), bygget gjennom samme `TraadSkjerm` som live. Ingen nettverk.
public struct DemoTraadKilde: TraadKilde {
    public enum Variant: Sendable, Equatable {
        case noen
        case tom
        #if DEBUG
        // Synsløkka (`--demo-traader=…`): finnes bare i DEBUG.
        case feil
        case ikkeInnlogget
        /// Henter aldri ferdig: «Henter»-tilstanden kan fotograferes.
        case treg
        #endif
    }

    private let variant: Variant
    private let nå: @Sendable () -> Date

    public init(variant: Variant = .noen, nå: @escaping @Sendable () -> Date = { Date() }) {
        self.variant = variant
        self.nå = nå
    }

    public func hent() async throws -> TraadSkjerm {
        #if DEBUG
        switch variant {
        case .feil: throw TraadflataFeil.nettverk("demo")
        case .ikkeInnlogget: throw TraadflataFeil.ikkeInnlogget
        case .treg: try await Task.sleep(for: .seconds(3600))
        default: break
        }
        #endif
        if variant == .tom { return TraadSkjerm(traader: [], nå: nå()) }
        return TraadSkjerm(traader: Self.traader(nå: nå()), nå: nå())
    }

    /// Til tester i App-målet (som ikke ser `internal`).
    public static var traaderForTest: [Traad] { traader(nå: Date()) }

    /// ALT her er syntetisk. Ikke lim inn noe fra serveren eller fra skjermbilder.
    static func traader(nå: Date) -> [Traad] {
        let min: TimeInterval = 60
        let prosjekt = TraadProsjekt(label: "00.00 eksempel")
        return [
            Traad(id: "demo-t1", tittel: "kode:eksempel-app", sistAktiv: nå.addingTimeInterval(-6 * min),
                  holder: TraadHolder(type: .plattform, status: "working", aktiv: true), prosjekt: prosjekt),
            Traad(id: "demo-t2", tittel: "kode:eksempel-app:ny-skjerm", sistAktiv: nå.addingTimeInterval(-23 * min),
                  holder: TraadHolder(type: .terminal, status: "blocked", aktiv: true), prosjekt: prosjekt, ko: 2),
            Traad(id: "demo-t3", tittel: "eksempel-agent", sistAktiv: nå.addingTimeInterval(-95 * min),
                  holder: TraadHolder(type: .plattform, status: "idle", aktiv: true), prosjekt: TraadProsjekt(label: "00.01 eksempel-drift")),
            Traad(id: "demo-t4", tittel: "eksempel-notater", sistAktiv: nå.addingTimeInterval(-7 * 3600), prosjekt: prosjekt),
            Traad(id: "demo-t5", tittel: "kode:eksempel-server:rydd-opp", sistAktiv: nå.addingTimeInterval(-26 * 3600),
                  holder: TraadHolder(type: .plattform, status: "idle", aktiv: false), prosjekt: prosjekt, ko: 1),
            Traad(id: "demo-t6", tittel: "eksempel-ukerapport", sistAktiv: nå.addingTimeInterval(-3 * 86_400)),
        ]
    }
}

/// Hovedfanene som FINNES. En fane for en skjerm som ikke er bygd er ikke med (ingen trykkbar plassholder).
public enum Hovedfane: String, CaseIterable, Sendable, Identifiable {
    case naa, traader

    public var id: String { rawValue }

    public var tittel: String {
        switch self {
        case .naa: "Nå"
        case .traader: "Tråder"
        }
    }

    public var identifier: String {
        switch self {
        case .naa: "tabNaa"
        case .traader: "tabTraader"
        }
    }

    /// Fanen appen åpner på. `--fane=traader` (synsløkka) finnes bare i DEBUG.
    public static func start(argumenter: [String]) -> Hovedfane {
        #if DEBUG
        if let a = argumenter.first(where: { $0.hasPrefix("--fane=") }),
           let f = Hovedfane(rawValue: String(a.dropFirst("--fane=".count))) { return f }
        #endif
        return .naa
    }
}
