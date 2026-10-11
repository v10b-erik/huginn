import Foundation

/// Hva vi vet om kontakten med trådflata, fra «Nå»s siste henting.
public enum Kontakt: Equatable, Sendable {
    case ukjent
    case ok(Date)
    /// Siste henting feilet. `kreverNyttToken`: 401 (tokenet er trukket).
    case feilet(kreverNyttToken: Bool)

    public enum Lampe: Sendable, Equatable { case ok, avvik, ingen }

    /// Lampen står alltid sammen med ordet (aldri farge alene).
    public var lampe: Lampe {
        switch self {
        case .ukjent: .ingen
        case .ok: .ok
        case .feilet: .avvik
        }
    }

    public var ord: String {
        switch self {
        case .ukjent: "HENTER"
        case .ok: "TILKOBLET"
        case .feilet(let nyttToken): nyttToken ? "IKKE INNLOGGET" : "FÅR IKKE KONTAKT"
        }
    }
}

/// Innholdet i tilkoblingsarket, som ren logikk så det kan testes uten UI: status (lampe + ORD + når), hele
/// adressen (aldri tokenet), hvilke handlinger som finnes, og feilen fra en handling som ikke gikk gjennom.
public struct ArkVisning: Equatable, Sendable {
    public var lampe: Kontakt.Lampe
    public var ord: String
    public var detalj: String?
    public var adresse: String?
    public var kanKobleFra: Bool
    public var kanByttTilDemo: Bool
    public var kanKoble: Bool
    public var kanBrukLagret: Bool
    public var feil: TilkoblingsFeil?

    public static let kobleFraTittel = "Koble fra trådflata?"
    /// Står under knappen, så konsekvensen er synlig før du trykker.
    public static let kobleFraKonsekvens = "Sletter tokenet fra Keychain. Du må lime det inn på nytt."
    public static let kobleFraBekreftelse = "Koble fra"

    public static func fra(
        tilstand: Innlogging.Tilstand, kontakt: Kontakt, harLagret: Bool, handlingsFeil: TilkoblingsFeil?,
        kalender: Calendar = .current
    ) -> ArkVisning {
        switch tilstand {
        case .koblet(let t):
            var detalj: String?
            if case .ok(let tid) = kontakt {
                let k = kalender.dateComponents([.hour, .minute], from: tid)
                detalj = "siste kontakt " + String(format: "%02d:%02d", k.hour ?? 0, k.minute ?? 0)
            }
            return ArkVisning(
                lampe: kontakt.lampe, ord: kontakt.ord, detalj: detalj, adresse: t.adresse,
                kanKobleFra: true, kanByttTilDemo: true, kanKoble: false, kanBrukLagret: false, feil: handlingsFeil
            )
        case .demo:
            return ArkVisning(
                lampe: .ingen, ord: "DEMO", detalj: "ingen forbindelse", adresse: nil,
                kanKobleFra: false, kanByttTilDemo: false, kanKoble: true, kanBrukLagret: harLagret, feil: handlingsFeil
            )
        case .laster, .ikkeKoblet, .kobler:
            return ArkVisning(
                lampe: .ingen, ord: "IKKE KOBLET", detalj: nil, adresse: nil,
                kanKobleFra: false, kanByttTilDemo: false, kanKoble: false, kanBrukLagret: false, feil: handlingsFeil
            )
        }
    }
}
