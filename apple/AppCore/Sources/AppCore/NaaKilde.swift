import Foundation

/// Hvor «Nå» henter innholdet fra. Viewet kjenner bare dette; demo og live byttes i App-målet.
public protocol NaaKilde: Sendable {
    func hent() async throws -> NaaSkjerm
}

/// Ekte data fra trådflata: `/api/naa` og `/api/traader` (begge med enhetstoken i klienten).
public struct LiveKilde: NaaKilde, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    private let klient: TraadflataKlient
    private let nå: @Sendable () -> Date
    private let kalender: Calendar

    public init(klient: TraadflataKlient, nå: @escaping @Sendable () -> Date = { Date() }, kalender: Calendar = .current) {
        self.klient = klient
        self.nå = nå
        self.kalender = kalender
    }

    public var description: String { "LiveKilde(\(klient.baseURL.host ?? "?"))" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: ["baseURL": klient.baseURL]) }

    public func hent() async throws -> NaaSkjerm {
        async let naa = klient.hentNaa()
        async let traader = klient.hentTraader()
        return NaaSkjerm(naa: try await naa, traader: try await traader, nå: nå(), kalender: kalender)
    }
}

/// Hvordan en feil vises: en avviks-lignende rad, ikke en dialog.
public struct NaaFeil: Sendable, Equatable {
    public var tittel: String
    public var detalj: String
    /// 401: tokenet er trukket eller ukjent. Å prøve igjen hjelper ikke; det som hjelper er å koble til på nytt.
    public var kreverNyttToken: Bool

    public init(tittel: String, detalj: String, kreverNyttToken: Bool = false) {
        self.tittel = tittel
        self.detalj = detalj
        self.kreverNyttToken = kreverNyttToken
    }

    /// 401 er en egen sak («Ikke innlogget»); alt annet er at flata ikke svarer. Detaljen er aldri
    /// svarinnholdet eller tokenet: det kan være samtaledata.
    public static func fra(_ feil: Error) -> NaaFeil {
        if let t = feil as? TraadflataFeil, t == .ikkeInnlogget {
            return NaaFeil(tittel: "Ikke innlogget", detalj: "Enhetstokenet er ikke gyldig for trådflata.", kreverNyttToken: true)
        }
        return NaaFeil(tittel: "Kan ikke nå trådflata", detalj: "Sjekk nettverket og prøv igjen.")
    }
}
