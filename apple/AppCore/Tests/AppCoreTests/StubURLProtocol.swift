import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct StubSvar {
    var status: Int
    var body: Data
    var headers: [String: String] = ["Content-Type": "application/json"]
}

/// Stubber nettverket per vert (host), så parallelle tester ikke deler handler.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> StubSvar

    private static let lås = NSLock()
    nonisolated(unsafe) private static var handlere: [String: Handler] = [:]
    nonisolated(unsafe) private static var forespørsler: [String: [URLRequest]] = [:]

    /// En klient-session og base-URL som bare treffer `handler`. Ingen nettverk.
    static func oppsett(handler: @escaping Handler) -> (session: URLSession, baseURL: URL, host: String) {
        let host = "stub-\(UUID().uuidString.lowercased()).invalid"
        lås.withLock { handlere[host] = handler }
        let konfig = URLSessionConfiguration.ephemeral
        konfig.protocolClasses = [StubURLProtocol.self]
        return (URLSession(configuration: konfig), URL(string: "https://\(host)")!, host)
    }

    static func sett(host: String) -> [URLRequest] {
        lås.withLock { forespørsler[host] ?? [] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let handler = Self.lås.withLock { () -> Handler? in
            Self.forespørsler[host, default: []].append(request)
            return Self.handlere[host]
        }
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        do {
            let svar = try handler(request)
            let http = HTTPURLResponse(url: url, statusCode: svar.status, httpVersion: "HTTP/1.1", headerFields: svar.headers)!
            client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: svar.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

enum Fixtur {
    static func data(_ navn: String) throws -> Data {
        let deler = navn.split(separator: ".", maxSplits: 1).map(String.init)
        guard let url = Bundle.module.url(forResource: deler[0], withExtension: deler[1], subdirectory: "Fixtures") else {
            throw URLError(.fileDoesNotExist)
        }
        return try Data(contentsOf: url)
    }
}
