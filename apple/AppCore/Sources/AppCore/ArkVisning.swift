import Foundation

/// Hva vi vet om kontakten med trådflata, fra «Nå»s siste henting.
public enum Kontakt: Equatable, Sendable {
    case ukjent
    case ok(Date)
    /// Siste henting feilet. `kreverNyttToken`: 401 (tokenet er trukket). `sist`: når verten sist svarte (`nil`: aldri).
    case feilet(kreverNyttToken: Bool, sist: Date? = nil)

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
        case .feilet(let nyttToken, _): nyttToken ? "IKKE INNLOGGET" : "FÅR IKKE KONTAKT"
        }
    }
}

/// Innholdet i tilkoblingsarket, som ren logikk så det kan testes uten UI: status (lampe + ORD + når), hele
/// adressen (aldri tokenet), hvilke handlinger som finnes, og feilen fra en handling som ikke gikk gjennom.
public struct ArkVisning: Equatable, Sendable {
    public var lampe: Kontakt.Lampe
    public var ord: String
    /// Teknisk tilleggsinfo (demo: «ingen forbindelse»).
    public var detalj: String?
    /// ALLTID til stede for en vert: «SISTE KONTAKT 17:54» eller «SISTE KONTAKT ALDRI», så «aldri svart» og
    /// «ikke bygd» ikke ser like ut. `nil` bare i demo (ingen vert).
    public var sisteKontakt: String?
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
            let sist: Date? =
                switch kontakt {
                case .ok(let tid): tid
                case .feilet(_, let sist): sist
                case .ukjent: nil
                }
            var tekst = "SISTE KONTAKT ALDRI"
            if let sist {
                let k = kalender.dateComponents([.hour, .minute], from: sist)
                tekst = "SISTE KONTAKT " + String(format: "%02d:%02d", k.hour ?? 0, k.minute ?? 0)
            }
            return ArkVisning(
                lampe: kontakt.lampe, ord: kontakt.ord, detalj: nil, sisteKontakt: tekst, adresse: t.adresse,
                kanKobleFra: true, kanByttTilDemo: true, kanKoble: false, kanBrukLagret: false, feil: handlingsFeil
            )
        case .demo:
            return ArkVisning(
                lampe: .ingen, ord: "DEMO", detalj: "ingen forbindelse", sisteKontakt: nil, adresse: nil,
                kanKobleFra: false, kanByttTilDemo: false, kanKoble: true, kanBrukLagret: harLagret, feil: handlingsFeil
            )
        case .laster, .ikkeKoblet, .kobler:
            return ArkVisning(
                lampe: .ingen, ord: "IKKE KOBLET", detalj: nil, sisteKontakt: nil, adresse: nil,
                kanKobleFra: false, kanByttTilDemo: false, kanKoble: false, kanBrukLagret: false, feil: handlingsFeil
            )
        }
    }
}
