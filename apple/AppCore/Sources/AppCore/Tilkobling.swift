import Foundation

/// Hvorfor en tilkobling ikke ble til noe. Meldingene er norske og beskriver årsaken uten å inneholde noe
/// brukeren har skrevet inn: aldri tokenet, aldri serverens svartekst.
public enum TilkoblingsFeil: Error, Sendable, Equatable {
    case adresseMangler
    /// Adressen lot seg ikke tolke som en nettadresse (ingen vert, ugyldige tegn, brukernavn/passord, spørring).
    case adresseUgyldig
    /// Ikke `https` (og ikke `http` mot loopback i et DEBUG-bygg).
    case adresseIkkeHttps
    case tokenMangler
    /// Serveren ignorerer tokens kortere enn `Tilkobling.minsteTokenLengde` (`TRAADFLATA_TOKENS` filtrerer `length >= 24`).
    case tokenForKort
    /// Mellomrom, linjeskift eller tegn utenfor skrivbar ASCII: et token er aldri slikt, og det kan ikke sendes i en header.
    case tokenUgyldigeTegn
    /// 401: trådflata kjenner ikke tokenet.
    case ikkeInnlogget
    /// Nettverksfeil eller tidsavbrudd.
    case ikkeNaabar
    /// Annen ikke-2xx fra serveren. Statuskoden er ikke hemmelig; svarteksten kan være det og tas aldri med.
    case tjenesteFeil(status: Int)
    /// 2xx, men svaret ble ikke forstått.
    case svarIkkeForstaatt
    case kunneIkkeLagre
    case kunneIkkeLese
    case kunneIkkeSlette

    /// Hører feilen til adressefeltet (ellers til token-feltet)? Styrer hvor feilraden står.
    public var gjelderAdresse: Bool {
        switch self {
        case .adresseMangler, .adresseUgyldig, .adresseIkkeHttps: true
        default: false
        }
    }

    /// Kort tilstandsord (aldri farge alene), vist i rødt over meldingen.
    public var ord: String {
        switch self {
        case .adresseMangler, .adresseUgyldig, .adresseIkkeHttps: "UGYLDIG ADRESSE"
        case .tokenMangler, .tokenForKort, .tokenUgyldigeTegn: "UGYLDIG TOKEN"
        case .ikkeInnlogget: "IKKE INNLOGGET"
        case .ikkeNaabar, .tjenesteFeil: "KAN IKKE KOBLE TIL"
        case .svarIkkeForstaatt: "UFORSTÅTT SVAR"
        case .kunneIkkeLagre, .kunneIkkeLese, .kunneIkkeSlette: "KEYCHAIN"
        }
    }

    public var melding: String {
        switch self {
        case .adresseMangler: "Skriv inn adressen til trådflata."
        case .adresseUgyldig: "Adressen er ikke en gyldig nettadresse. Bruk formen https://vert:port."
        case .adresseIkkeHttps: "Adressen må starte med https://. Tokenet sendes aldri over en ukryptert forbindelse."
        case .tokenMangler: "Lim inn enhetstokenet."
        case .tokenForKort: "Tokenet er for kort. Trådflata ignorerer tokens med færre enn \(Tilkobling.minsteTokenLengde) tegn, så det kan aldri virke."
        case .tokenUgyldigeTegn: "Tokenet inneholder mellomrom, linjeskift eller andre tegn et token ikke har. Lim inn bare selve tokenet."
        case .ikkeInnlogget: "Tokenet er ukjent for trådflata. Sjekk at hele tokenet er limt inn, og at det ikke er trukket tilbake."
        case .ikkeNaabar: "Trådflata kan ikke nås. Sjekk adressen, og at tailnettet (Tailscale) er på."
        case .tjenesteFeil(let s): "Trådflata svarte med en feil (HTTP \(s)). Sjekk adressen, eller prøv igjen om litt."
        case .svarIkkeForstaatt: "Svaret fra trådflata ble ikke forstått. Er adressen riktig, og er appen og trådflata av samme versjon?"
        case .kunneIkkeLagre: "Tilkoblingen ble bekreftet, men kunne ikke lagres i Keychain. Den nye tilkoblingen ble ikke lagret."
        case .kunneIkkeLese: "Keychain kunne ikke leses, så en lagret tilkobling er ikke brukt. Ingenting er endret."
        case .kunneIkkeSlette: "Tilkoblingen kunne ikke fjernes fra Keychain. Du er fortsatt koblet til."
        }
    }

    /// Til VoiceOver: ordet og meldingen som én setning, aldri noe innskrevet.
    public var tilgjengeligTekst: String { "\(ord.lowercased()). \(melding)" }
}

/// Adresse og enhetstoken, validert og normalisert. Tokenet skal aldri havne i en logg, en feilmelding, en
/// `dump` eller et tilgjengelighetsmerke, så alle beskrivelser er redigert.
public struct Tilkobling: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public static let minsteTokenLengde = 24
    /// Foreslått adresse i «Koble til»-skjermen (ikke hemmelig).
    public static let standardAdresse = "https://ygg-v1.tail908368.ts.net:8444"

    public let baseURL: URL
    public let token: String

    /// Uvalidert. Bruk `fra(adresse:token:tillatHttpLoopback:)` for alt brukeren har skrevet.
    public init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    /// Antall tegn i tokenet slik det ville blitt lagret (trimmet). Vises mot minstekravet mens du skriver.
    public static func tokenLengde(_ token: String) -> Int {
        token.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    public static func tokenLangNok(_ token: String) -> Bool { tokenLengde(token) >= minsteTokenLengde }

    public var adresse: String { baseURL.absoluteString }
    public var vert: String { baseURL.host ?? "?" }

    public var description: String { "Tilkobling(\(vert))" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: ["baseURL": baseURL]) }

    /// Trimmer, krever vert, krever `https` (unntak: `http` mot `localhost`/`127.0.0.1` når `tillatHttpLoopback`),
    /// fjerner etterhengende `/` og krever et token på minst 24 tegn.
    public static func fra(adresse: String, token: String, tillatHttpLoopback: Bool = false) throws(TilkoblingsFeil) -> Tilkobling {
        let a = adresse.trimmingCharacters(in: .whitespacesAndNewlines)
        let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = try normaliser(adresse: a, tillatHttpLoopback: tillatHttpLoopback)
        guard !t.isEmpty else { throw .tokenMangler }
        guard t.unicodeScalars.allSatisfy({ $0.value > 0x20 && $0.value < 0x7F }) else { throw .tokenUgyldigeTegn }
        guard t.count >= minsteTokenLengde else { throw .tokenForKort }
        return Tilkobling(baseURL: url, token: t)
    }

    private static func normaliser(adresse: String, tillatHttpLoopback: Bool) throws(TilkoblingsFeil) -> URL {
        guard !adresse.isEmpty else { throw .adresseMangler }
        // «vert:port» uten skjema tolkes av URL som et skjema; kreves eksplisitt i stedet.
        guard let skille = adresse.range(of: "://") else { throw .adresseIkkeHttps }
        let skjema = adresse[..<skille.lowerBound].lowercased()
        guard skjema == "https" || skjema == "http" else { throw .adresseIkkeHttps }
        guard var deler = URLComponents(string: adresse), let vert = deler.host?.lowercased(), !vert.isEmpty else {
            throw .adresseUgyldig
        }
        if skjema == "http" {
            guard tillatHttpLoopback, vert == "localhost" || vert == "127.0.0.1" else { throw .adresseIkkeHttps }
        }
        guard deler.user == nil, deler.password == nil, deler.query == nil, deler.fragment == nil else {
            throw .adresseUgyldig
        }
        deler.scheme = skjema
        deler.host = vert
        var sti = deler.path
        while sti.hasSuffix("/") { sti.removeLast() }
        deler.path = sti
        guard let url = deler.url else { throw .adresseUgyldig }
        return url
    }

    // MARK: - lagringsformat

    private struct Lagret: Codable {
        var adresse: String
        var token: String
    }

    /// Verdien som legges i Keychain: JSON `{adresse, token}`.
    public func json() throws -> Data {
        try JSONEncoder().encode(Lagret(adresse: adresse, token: token))
    }

    /// Leser tilbake og validerer på nytt (en verdi fra en annen bygg-type, f.eks. `http` fra et DEBUG-bygg,
    /// skal ikke slippe forbi i release).
    public static func fra(json: Data, tillatHttpLoopback: Bool = false) throws -> Tilkobling {
        let l: Lagret
        do { l = try JSONDecoder().decode(Lagret.self, from: json) } catch { throw LagerFeil.ugyldigInnhold }
        do { return try fra(adresse: l.adresse, token: l.token, tillatHttpLoopback: tillatHttpLoopback) } catch { throw LagerFeil.ugyldigInnhold }
    }

    /// Kilden «Nå» skal bruke for denne tilkoblingen.
    public var kildeValg: KildeValg { .live(url: baseURL, token: token) }
}

/// Feil fra et lager. Aldri med verdier; `status` er Keychains `OSStatus`.
public enum LagerFeil: Error, Sendable, Equatable {
    case ugyldigInnhold
    case keychain(status: Int32)
}

/// Hvor den bekreftede tilkoblingen bor (Keychain i appen, minne i tester).
public protocol TilkoblingLager: Sendable {
    func les() throws -> Tilkobling?
    func lagre(_ tilkobling: Tilkobling) throws
    func slett() throws
}

/// Lager i minnet, til tester. Kan fås til å feile per operasjon.
public final class MinneLager: TilkoblingLager, @unchecked Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    private let lås = NSLock()
    private var verdi: Tilkobling?
    private var _feil: [Operasjon: LagerFeil] = [:]
    private var _antallSkrivinger = 0

    public enum Operasjon: Sendable { case les, lagre, slett }

    public init(_ verdi: Tilkobling? = nil) { self.verdi = verdi }

    public var innhold: Tilkobling? { lås.withLock { verdi } }
    public var antallSkrivinger: Int { lås.withLock { _antallSkrivinger } }

    public func feilVed(_ op: Operasjon, _ feil: LagerFeil?) {
        lås.withLock { _feil[op] = feil }
    }

    public func les() throws -> Tilkobling? {
        try lås.withLock {
            if let f = _feil[.les] { throw f }
            return verdi
        }
    }

    public func lagre(_ tilkobling: Tilkobling) throws {
        try lås.withLock {
            if let f = _feil[.lagre] { throw f }
            verdi = tilkobling
            _antallSkrivinger += 1
        }
    }

    public func slett() throws {
        try lås.withLock {
            if let f = _feil[.slett] { throw f }
            verdi = nil
            _antallSkrivinger += 1
        }
    }

    public var description: String { "MinneLager(\(verdi == nil ? "tomt" : "fylt"))" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

// MARK: - bekreftelse

/// Bygger klienten for en tilkobling. Injiserbar så tester kan bruke en stubbet `URLSession`.
public typealias KlientFabrikk = @Sendable (Tilkobling) -> TraadflataKlient

public let standardKlientFabrikk: KlientFabrikk = { TraadflataKlient(baseURL: $0.baseURL, token: $0.token) }

extension TilkoblingsFeil {
    /// Klientens feil til en melding uten innhold. Svartekst og dekodingsdetaljer (kan være samtaledata) droppes.
    public static func fra(_ feil: TraadflataFeil) -> TilkoblingsFeil {
        switch feil {
        case .ikkeInnlogget: .ikkeInnlogget
        case .nettverk: .ikkeNaabar
        case .http(let status, _): .tjenesteFeil(status: status)
        case .dekoding, .ugyldigSvar: .svarIkkeForstaatt
        }
    }
}

/// Bekrefter at trådflata godtar tokenet ved å hente `/api/naa`. Kaster bare `TilkoblingsFeil` (eller
/// `CancellationError` når oppgaven avbrytes). Rører ikke noe lager: det er kallerens jobb, og først etter suksess.
public func bekreftTilkobling(_ t: Tilkobling, klient: KlientFabrikk = standardKlientFabrikk) async throws {
    do {
        _ = try await klient(t).hentNaa()
    } catch let f as TraadflataFeil {
        throw TilkoblingsFeil.fra(f)
    } catch is CancellationError {
        throw CancellationError()
    } catch let e as URLError where e.code == .cancelled {
        throw CancellationError()
    } catch {
        throw TilkoblingsFeil.ikkeNaabar
    }
}
