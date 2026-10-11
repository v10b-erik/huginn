import Foundation

/// Innholdet fra prototypen (`design/utforskning/proeve-b3.html`), bygget gjennom de samme modellene
/// og den samme `NaaSkjerm`-logikken som live, så demoen bruker ekte kodeveier. Alt er relativt til
/// `nå`, så «Neste» aldri peker bakover. Ingen nettverk.
public struct DemoKilde: NaaKilde {
    public enum Variant: Sendable, Equatable {
        /// Dag med en godkjenning og et avvik.
        case avvik
        /// Rolig dag: tallet er 0.
        case rolig
    }

    private let variant: Variant
    private let nå: @Sendable () -> Date
    private let kalender: Calendar

    public init(variant: Variant = .avvik, nå: @escaping @Sendable () -> Date = { Date() }, kalender: Calendar = .current) {
        self.variant = variant
        self.nå = nå
        self.kalender = kalender
    }

    public func hent() async throws -> NaaSkjerm { skjerm(nå: nå()) }

    public func skjerm(nå: Date) -> NaaSkjerm {
        let (naa, traader) = data(nå: nå)
        var s = NaaSkjerm(naa: naa, traader: traader, nå: nå, kalender: kalender)
        if variant == .avvik, !s.godkjenninger.isEmpty {
            // Klasse og «rent» finnes ikke i serverens kort (ennå); demoen viser hva båndene ser ut som.
            s.godkjenninger[0].klasse = "Høyrisiko"
            s.godkjenninger[0].kildeRen = true
        }
        return s
    }

    private func data(nå: Date) -> (Naa, [Traad]) {
        let min: TimeInterval = 60
        func treffer(_ time: Int, _ minutt: Int, etter: Date, ukedag: Int? = nil) -> Date {
            var komp = DateComponents(hour: time, minute: minutt)
            if let ukedag { komp.weekday = ukedag }
            return kalender.nextDate(after: etter, matching: komp, matchingPolicy: .nextTime) ?? etter
        }
        let trening = treffer(18, 0, etter: nå)
        let standup = treffer(8, 30, etter: nå, ukedag: 2)  // mandag
        let avvik: [NaaAvvik] = variant == .rolig ? [] : [
            NaaAvvik(art: "jobb", navn: "hermod-backup", tekst: "siste kjøring 03:10",
                     ts: treffer(3, 10, etter: nå.addingTimeInterval(-86_400)), lenke: nil)
        ]
        let kort: [NaaKort] = variant == .rolig ? [] : [
            NaaKort(id: "demo-alarm", name: "alarm", describe: "Armere alarmen", status: "pending",
                    expiresAt: nil, createdAt: nå.addingTimeInterval(-(3 * min + 12)), agent: nil,
                    threadKey: "kode:v10b:ajax-fix",
                    actions: [.init(key: "approve", label: "Godkjenn"), .init(key: "deny", label: "Avslå")])
        ]
        let naa = Naa(
            kort: kort, avvik: avvik,
            kalender: [NaaKalenderHendelse(tittel: "Trening", kalender: nil, ts: trening, heleDagen: false),
                       NaaKalenderHendelse(tittel: "Standup", kalender: nil, ts: standup, heleDagen: false)]
        )
        let ajaxId = variant == .rolig ? "demo-ajax-fix" : "kode:v10b:ajax-fix"
        let traader = [
            Traad(id: "demo-huginn", tittel: "kode:huginn", sistAktiv: nå.addingTimeInterval(-8 * min),
                  holder: TraadHolder(type: .plattform, status: "working", aktiv: true)),
            Traad(id: "demo-cto", tittel: "cto", sistAktiv: nå.addingTimeInterval(-60 * min),
                  holder: TraadHolder(type: .plattform, status: "idle", aktiv: true)),
            Traad(id: ajaxId, tittel: "kode:v10b:ajax-fix", sistAktiv: nå.addingTimeInterval(-125 * min),
                  holder: TraadHolder(type: .plattform, status: "idle", aktiv: true)),
        ]
        return (naa, traader)
    }
}
