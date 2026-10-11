import Foundation
import Observation

/// Orkestrerer et svar: bekreftelse → autentisering → forsendelse → oppfriskning, med `Svar` som eneste kilde til
/// hva som er lov. Alt eksternt er injisert (`Autentisering`, `send`, `oppfrisk`), så hele flyten testes uten UI og
/// nettverk. Tjenesten kjenner ikke tokenet: `send` er en closure som klienten eier.
@MainActor @Observable
public final class SvarTjeneste {
    /// Sender ett svar. Kalles høyst én gang per forsøk; feil uten svar kastes (aldri retry her eller i klienten).
    public typealias Send = @Sendable (_ kortId: String, _ key: String) async throws -> SvarUtfall
    public typealias Oppfrisk = @MainActor @Sendable () async -> Void

    public private(set) var svar = Svar()
    /// Når siste avgjørelse ble registrert (til kvitteringen).
    public private(set) var sistFerdig: Date?

    @ObservationIgnored private let autentisering: any Autentisering
    @ObservationIgnored private let send: Send
    @ObservationIgnored private let oppfrisk: Oppfrisk
    @ObservationIgnored private let nå: @Sendable () -> Date

    public init(autentisering: any Autentisering, send: @escaping Send, oppfrisk: @escaping Oppfrisk,
                nå: @escaping @Sendable () -> Date = { Date() }) {
        self.nå = nå
        self.autentisering = autentisering
        self.send = send
        self.oppfrisk = oppfrisk
    }

    public var tilstand: Svar.Tilstand { svar.tilstand }

    /// Godkjenn/Avslå trykket på brikken: åpner bekreftelsen. Sender ingenting.
    public func velg(_ forespørsel: Svar.Forespørsel) {
        svar.velg(forespørsel)
    }

    /// «Avbryt», eller kvittering av en feil/usikkerhet. Ingenting sendes.
    public func lukk() {
        svar.lukk()
    }

    /// Knappen i bekreftelsen. Kjører hele resten av flyten og kommer tilbake når den er ferdig (inkl. oppfriskning).
    /// Et nytt kall mens flyten pågår gjør ingenting: maskinen er ikke lenger i `.bekrefter`.
    public func bekreft() async {
        var kommando = svar.bekreft()
        while kommando != .ingenting {
            switch kommando {
            case .autentiser(let forsøk):
                let utfall = await autentisering.autentiser(begrunnelse: forsøk.forespørsel.begrunnelse)
                kommando = svar.autentisert(id: forsøk.id, utfall: utfall)
            case .send(let forsøk):
                // Beltet utenpå selen: maskinen gir bare `.send` for Godkjenn etter `autentisert(.ok)`.
                guard !forsøk.forespørsel.valg.krevAutentisering || forsøk.autentisert else {
                    svar.stopp(id: forsøk.id)
                    return
                }
                let resultat: Svar.Resultat
                do {
                    resultat = .utfall(try await send(forsøk.forespørsel.kortId, forsøk.forespørsel.valg.key))
                } catch let feil as TraadflataFeil {
                    resultat = .feil(feil)
                } catch {
                    // Alt annet uten svar (også avbrutt) er usikkert, aldri «ikke sendt».
                    resultat = .feil(.nettverk("ukjent feil"))
                }
                kommando = svar.resultat(id: forsøk.id, resultat)
                if case .ferdig = svar.tilstand { sistFerdig = nå() }
            case .oppfrisk:
                await oppfrisk()
                kommando = .ingenting
            case .ingenting:
                break
            }
        }
    }
}
