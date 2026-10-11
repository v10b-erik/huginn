import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum TraadflataFeil: Error, Sendable, Equatable {
    /// 401: tokenet er ukjent for trådflata.
    case ikkeInnlogget
    /// Annen ikke-2xx; `melding` er serverens `{"error": …}` når den finnes.
    case http(status: Int, melding: String?)
    /// Svaret var ikke HTTP.
    case ugyldigSvar
    /// 2xx med innhold som ikke lot seg tolke. Aldri selve innholdet — det kan være samtaledata.
    case dekoding(String)
    case nettverk(String)
    /// Kort-id-en har ikke formen serveren godtar (`^[\w-]{6,64}$`). Ingenting ble sendt.
    case ugyldigKortId
}

/// Serverens svar på et Godkjenn/Avslå (`POST /api/godkjenning/<id>`). Feil som ikke er et svar (401, nettverk,
/// tidsavbrudd, 5xx) er `TraadflataFeil`, ikke et utfall: der vet ikke klienten hva serveren gjorde.
public enum SvarUtfall: Sendable, Equatable {
    /// 2xx: serveren har registrert avgjørelsen.
    case avgjort
    /// 409: kortet var allerede avgjort/avslått, eller kunne ikke avgjøres. Serverens `error`-tekst, når den finnes.
    case alleredeAvgjort(String?)
    /// 404.
    case ukjentKort
    /// 400: manglende eller ukjent `key`.
    case ugyldigValg
}

/// Async klient mot trådflata (yggdrasil/core/traadflata.ts). Autentiserer med
/// `Authorization: Bearer <enhetstoken>`; flata bruker samme token som cookie i nettleseren.
public struct TraadflataKlient: Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public let baseURL: URL
    private let token: String
    private let session: URLSession

    public init(baseURL: URL, token: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    /// Tokenet skal aldri havne i en logg, en feilmelding eller en `dump`.
    public var description: String { "TraadflataKlient(\(baseURL.host ?? "?"))" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: ["baseURL": baseURL]) }

    /// GET /api/naa
    public func hentNaa() async throws -> Naa {
        try await hent("/api/naa")
    }

    /// Kort-id-en slik serveren matcher den: `^[\w-]{6,64}$` med `\w` = ASCII-bokstav, siffer og understrek (JS-regex uten
    /// `u`-flagg). Sjekkes FØR en URL bygges, så ingenting uten for formen kan bli en del av stien.
    public static func erGyldigKortId(_ id: String) -> Bool {
        let bytes = id.utf8
        guard (6...64).contains(bytes.count) else { return false }
        return bytes.allSatisfy { b in
            (b >= 48 && b <= 57) || (b >= 65 && b <= 90) || (b >= 97 && b <= 122) || b == 95 || b == 45
        }
    }

    /// POST /api/godkjenning/<kortId> `{"key": …}`: Godkjenn (`approve` eller en av kortets handlinger) eller Avslå
    /// (`deny`). Godkjenn UTFØRER handlingen på serveren, så den kalles bare etter bekreftelse og autentisering
    /// (se `Svar`/`SvarTjeneste`); klienten gjør ingenting av det selv.
    ///
    /// **Ingen retry, aldri.** Feiler forespørselen uten svar (nettverk, tidsavbrudd, avbrutt oppgave), vet vi ikke om den
    /// gikk gjennom: `TraadflataFeil.nettverk`, og kalleren må behandle det som «usikkert». Et svar utenfor listen
    /// (f.eks. 5xx) kastes som `.http`; heller ikke det er et vitnesbyrd om at ingenting skjedde.
    public func svar(kortId: String, key: String) async throws -> SvarUtfall {
        guard Self.erGyldigKortId(kortId) else { throw TraadflataFeil.ugyldigKortId }
        guard !key.isEmpty else { return .ugyldigValg }
        struct Kropp: Encodable { var key: String }
        let kropp = try JSONEncoder().encode(Kropp(key: key))
        let r = try forespørsel("/api/godkjenning/\(kortId)", metode: "POST", kropp: kropp)
        let data: Data
        let svar: URLResponse
        do {
            (data, svar) = try await session.data(for: r)
        } catch {
            // Alt uten svar er «usikkert», også avbrutt: forespørselen kan være på vei eller levert.
            let beskrivelse = (error as? URLError).map { $0.code == .cancelled ? "avbrutt" : $0.localizedDescription } ?? "ukjent feil"
            throw TraadflataFeil.nettverk(beskrivelse)
        }
        guard let http = svar as? HTTPURLResponse else { throw TraadflataFeil.ugyldigSvar }
        switch http.statusCode {
        case 200..<300: return .avgjort
        case 401: throw TraadflataFeil.ikkeInnlogget
        case 409: return .alleredeAvgjort(Self.feilmelding(data))
        case 404: return .ukjentKort
        case 400: return .ugyldigValg
        default: throw TraadflataFeil.http(status: http.statusCode, melding: Self.feilmelding(data))
        }
    }

    /// GET /api/traader — flatas standardutvalg (nyeste først, siste 30 dager, ikke arkivert).
    public func hentTraader() async throws -> [Traad] {
        try await hent("/api/traader")
    }

    /// Serverens datoer er både epoch-millisekunder (`sistAktiv`) og ISO 8601 med
    /// brøksekunder (`toISOString()`); én strategi tar begge.
    public static func dekoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dekoder in
            let c = try dekoder.singleValueContainer()
            if let ms = try? c.decode(Double.self) {
                return Date(timeIntervalSince1970: ms / 1000)
            }
            let tekst = try c.decode(String.self)
            if let dato = iso(tekst) { return dato }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "ugyldig dato")
        }
        return d
    }

    public static func koder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { dato, koder in
            var c = koder.singleValueContainer()
            try c.encode(dato.formatted(isoStil))
        }
        return e
    }

    private static let isoStil = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    private static func iso(_ tekst: String) -> Date? {
        if let d = try? Date(tekst, strategy: isoStil) { return d }
        return try? Date(tekst, strategy: .iso8601)
    }

    private func hent<T: Decodable>(_ sti: String) async throws -> T {
        let (data, svar) = try await send(forespørsel(sti))
        guard let http = svar as? HTTPURLResponse else { throw TraadflataFeil.ugyldigSvar }
        switch http.statusCode {
        case 200..<300: break
        case 401: throw TraadflataFeil.ikkeInnlogget
        default: throw TraadflataFeil.http(status: http.statusCode, melding: Self.feilmelding(data))
        }
        do {
            return try Self.dekoder().decode(T.self, from: data)
        } catch {
            throw TraadflataFeil.dekoding(String(describing: error))
        }
    }

    private func forespørsel(_ sti: String, metode: String = "GET", kropp: Data? = nil) throws -> URLRequest {
        guard var deler = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw TraadflataFeil.ugyldigSvar
        }
        var prefiks = deler.path
        while prefiks.hasSuffix("/") { prefiks.removeLast() }
        deler.path = prefiks + sti
        guard let url = deler.url else { throw TraadflataFeil.ugyldigSvar }
        var r = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        r.httpMethod = metode
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if let kropp {
            r.httpBody = kropp
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        // Aldri `Origin`: serveren slipper gjennom forespørsler uten, og en native klient har ingen.
        return r
    }

    private func send(_ r: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: r)
        } catch let e as URLError where e.code != .cancelled {
            throw TraadflataFeil.nettverk(e.localizedDescription)
        }
    }

    private static func feilmelding(_ data: Data) -> String? {
        struct Svar: Decodable { var error: String? }
        return (try? JSONDecoder().decode(Svar.self, from: data))?.error
    }
}
