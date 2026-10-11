import Foundation

/// Demoens «server» for Godkjenn/Avslå: avgjør lokalt, uten nettverk. Kortet forsvinner fra `DemoKilde` når det er
/// avgjort, så hele flyten kan vises i `--demo`. Delt mellom kilden og svar-closuren (samme objekt).
///
/// `atferd` og `langtKort` er synsløkke-verktøy (DEBUG-argumenter, se `KildeValg.demoSvar`); i release er de alltid
/// standard.
public final class DemoAvgjort: @unchecked Sendable {
    public enum Atferd: String, Sendable, Equatable {
        /// Avgjør etter en kort pause, og kortet forsvinner.
        case avgjort
        /// Svarer aldri (til «Sender …» kan fotograferes).
        case henger
        /// Nettverksfeil uten svar: «usikkert».
        case usikkert
        /// 409: kortet var allerede avgjort.
        case alleredeAvgjort
    }

    public let atferd: Atferd
    /// Demokortet får en lang, flerlinjet tekst (til å vise at hele teksten rommes i bekreftelsen).
    public let langtKort: Bool
    private let lås = NSLock()
    private var ider: Set<String> = []

    public init(atferd: Atferd = .avgjort, langtKort: Bool = false) {
        self.atferd = atferd
        self.langtKort = langtKort
    }

    public func erAvgjort(_ id: String) -> Bool { lås.withLock { ider.contains(id) } }

    /// Gjør det serveren ville gjort, uten nettverk. Samme kontrakt som `TraadflataKlient.svar`.
    public func svar(kortId: String, key: String) async throws -> SvarUtfall {
        guard TraadflataKlient.erGyldigKortId(kortId) else { throw TraadflataFeil.ugyldigKortId }
        switch atferd {
        case .avgjort:
            try await Task.sleep(for: .milliseconds(600))
            lås.withLock { _ = ider.insert(kortId) }
            return .avgjort
        case .henger:
            try await Task.sleep(for: .seconds(3600))
            return .avgjort
        case .usikkert:
            try await Task.sleep(for: .milliseconds(600))
            throw TraadflataFeil.nettverk("demo")
        case .alleredeAvgjort:
            try await Task.sleep(for: .milliseconds(600))
            return .alleredeAvgjort("kortet er allerede avgjort")
        }
    }

    /// Den lange demoteksten: syntetisk, flere avsnitt og en lang uknekkelig linje. Første linje er også kortets mål.
    static let langTekstForsteLinje = "Rull ut eksempeltjenesten til produksjon"
    static let langTekst = """
        \(langTekstForsteLinje)

        Dette er en syntetisk eksempeltekst som viser hvor mye et godkjenningskort kan bære. Ingenting her er ekte.

        Hva som skjer hvis du godkjenner:
        1. Eksempeltjenesten bygges fra gren eksempel-gren (commit 0123abc).
        2. Databasemigrasjonene kjøres mot eksempel-databasen.
        3. Trafikken flyttes over, og forrige versjon beholdes i ti minutter for tilbakerulling.
        4. En helsesjekk kjøres hvert minutt i et kvarter. Feiler den to ganger, rulles alt tilbake.

        Berørt: https://eksempel.example.com/helse?sjekk=EXAMPLE0123456789abcdef0123456789abcdef0123456789abcdef

        Risiko: høy. Tjenesten er nede i omtrent tre sekunder under flyttingen. Avslå hvis du ikke vil at det skjer nå.
        """
}
