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
    /// Kvittering for siste registrerte avgjørelse. Eget felt, ikke tilstanden: et nytt valg (kvitteringen låser ingenting)
    /// bytter tilstand, men kvitteringen står til den lukkes.
    public struct Kvittering: Sendable, Equatable {
        public var forespørsel: Svar.Forespørsel
        public var tid: Date
    }

    public private(set) var kvittering: Kvittering?
    /// Kort serveren har registrert som avgjort (eller sa var det) i denne økten. Settes i det øyeblikket svaret kommer,
    /// synkront, før oppfriskningen og uavhengig av hva som velges etterpå: et avgjort kort kan ikke tapes av rekkefølgen.
    public private(set) var avgjorte: Set<String> = []

    public var sistFerdig: Date? { kvittering?.tid }

    public func lukkKvittering() { kvittering = nil }

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
                if kommando == .oppfrisk {
                    switch svar.tilstand {
                    case .ferdig(let f) where f == forsøk.forespørsel:
                        avgjorte.insert(f.kortId)
                        kvittering = Kvittering(forespørsel: f, tid: nå())
                    case .feil(.alleredeAvgjort):
                        avgjorte.insert(forsøk.forespørsel.kortId)
                    default: break
                    }
                }
            case .oppfrisk:
                await oppfrisk()
                kommando = .ingenting
            case .ingenting:
                break
            }
        }
    }
}
