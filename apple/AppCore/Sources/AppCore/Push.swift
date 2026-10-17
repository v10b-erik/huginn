import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Hva et trykk på et varsel skal åpne. `userInfo["kjerne"]` er `{type, id}`, og er upålitelig inndata: alt som
/// ikke er nøyaktig en godkjenning med en gyldig kort-id gir `.ukjent`. Et trykk åpner bare; det avgjør aldri noe.
public enum PushRute: Sendable, Equatable {
    case godkjenning(String)
    case ukjent

    public static func parse(userInfo: [AnyHashable: Any]) -> PushRute {
        guard let kjerne = userInfo["kjerne"] as? [String: Any],
              let type = kjerne["type"] as? String, type == "godkjenning",
              let id = kjerne["id"] as? String, TraadflataKlient.erGyldigKortId(id)
        else { return .ukjent }
        return .godkjenning(id)
    }
}

public enum PushMiljo: String, Sendable, Equatable, Codable {
    case sandbox
    case produksjon
}

/// Et APNs-enhetstoken som hex. Er en hemmelighet på linje med bearer-tokenet: aldri i logg, feilmelding,
/// `description` eller `dump`. Vis bare `fingeravtrykk`.
public struct PushToken: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    let hex: String

    /// Fra rå token-data (`didRegisterForRemoteNotificationsWithDeviceToken`). `nil` utenfor 32...100 byte (64–200 hex).
    public init?(data: Data) {
        guard (32...100).contains(data.count) else { return nil }
        hex = data.map { String(format: "%02x", $0) }.joined()
    }

    /// Fra hex-tekst (tester, lagret verdi). Samme krav som serveren: 64–200 hex-tegn.
    public init?(hex: String) {
        let h = hex.lowercased()
        guard (64...200).contains(h.utf8.count), h.utf8.allSatisfy({ ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) })
        else { return nil }
        self.hex = h
    }

    /// `abcdef…1234`: første 6 og siste 4 tegn, som `kjerne-enhet list`.
    public var fingeravtrykk: String { "\(hex.prefix(6))…\(hex.suffix(4))" }

    public var description: String { "PushToken(\(fingeravtrykk))" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: ["fingeravtrykk": fingeravtrykk]) }
}

extension TraadflataKlient {
    /// POST /api/push/token `{token, miljo}`: melder enhetens APNs-token som kandidat. Svar 200 `{ok:true}`.
    /// **Ett forsøk**, ingen retry (kalleren sender én gang per oppstart/tokenendring). Feil bærer aldri tokenet.
    public func registrerPush(token: PushToken, miljo: PushMiljo) async throws {
        struct Kropp: Encodable { var token: String; var miljo: String }
        let kropp = try JSONEncoder().encode(Kropp(token: token.hex, miljo: miljo.rawValue))
        let r = try forespørsel("/api/push/token", metode: "POST", kropp: kropp)
        let svar: URLResponse
        let data: Data
        do {
            (data, svar) = try await session.data(for: r)
        } catch {
            let b = (error as? URLError).map { $0.code == .cancelled ? "avbrutt" : $0.localizedDescription } ?? "ukjent feil"
            throw TraadflataFeil.nettverk(b)
        }
        guard let http = svar as? HTTPURLResponse else { throw TraadflataFeil.ugyldigSvar }
        switch http.statusCode {
        case 200..<300: return
        case 401: throw TraadflataFeil.ikkeInnlogget
        default: throw TraadflataFeil.http(status: http.statusCode, melding: Self.feilmelding(data))
        }
    }
}

/// Skal appen spørre om varsler nå? Ren beslutning (testet), tatt når en live tilkobling står. En lagret live-tilkobling
/// betyr at Kobling har skjedd; spør derfor bare når svaret ikke er gitt. Aldri for demo, aldri uten live kilde.
public enum PushTillatelse {
    public enum Status: Sendable, Equatable { case ikkeAvgjort, avslatt, tillatt, annet }

    public static func skalSpoerre(status: Status, erLive: Bool, hoppOver: Bool) -> Bool {
        erLive && !hoppOver && status == .ikkeAvgjort
    }
}

extension PushRute {
    /// Hva «Nå» skal gjøre etter et trykk på et godkjenningsvarsel. `ventende` er ider på kortene i skjermen, `nil` før noen
    /// skjerm finnes. `hentingLyktes` er `true` bare når en henting STARTET ETTER trykket faktisk ga en ny skjerm.
    /// «Allerede avgjort» konkluderes bare på ferske data; tom skjerm før første henting og hentefeil er «ingenting ennå».
    public enum Utfall: Sendable, Equatable {
        case fremhev(String)
        case alleredeAvgjort
        case ingentingEnnaa
    }

    public static func utfall(id: String, ventende: [String]?, hentingLyktes: Bool) -> Utfall {
        guard hentingLyktes, let ventende else { return .ingentingEnnaa }
        return ventende.contains(id) ? .fremhev(id) : .alleredeAvgjort
    }
}

extension PushRute {
    /// Hvilke leverte varsler som er foreldet: bare GODKJENNINGSVARSLER (gyldig `{type:"godkjenning", id}`) hvis kort ikke
    /// finnes blant `gjeldende`. Alt annet (andre typer, ugyldig id, varsler uten `kjerne`, f.eks. kritiske) slettes aldri.
    public static func foreldede(levert: [(identifier: String, userInfo: [AnyHashable: Any])], gjeldende: Set<String>) -> [String] {
        levert.compactMap { n in
            guard case .godkjenning(let id) = parse(userInfo: n.userInfo), !gjeldende.contains(id) else { return nil }
            return n.identifier
        }
    }
}
