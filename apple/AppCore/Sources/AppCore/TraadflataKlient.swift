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

    private func forespørsel(_ sti: String) throws -> URLRequest {
        guard var deler = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw TraadflataFeil.ugyldigSvar
        }
        var prefiks = deler.path
        while prefiks.hasSuffix("/") { prefiks.removeLast() }
        deler.path = prefiks + sti
        guard let url = deler.url else { throw TraadflataFeil.ugyldigSvar }
        var r = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        r.httpMethod = "GET"
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
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
