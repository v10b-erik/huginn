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
        /// Ekte FORM, syntetisk innhold: lange mål med tekniske tokens, en lang kalendertittel, en heldagshendelse,
        /// ingen kort. Finnes for at layouten kan sees og regresjonstestes uten ekte data (`--demo-ekte`).
        case ekte
    }

    private let variant: Variant
    private let nå: @Sendable () -> Date
    private let kalender: Calendar
    private let avgjort: DemoAvgjort?

    /// - Parameter avgjort: demoens lokale «server»; kort den har avgjort (og deres «venter»-avvik) vises ikke lenger.
    public init(variant: Variant = .avvik, nå: @escaping @Sendable () -> Date = { Date() }, kalender: Calendar = .current,
                avgjort: DemoAvgjort? = nil) {
        self.avgjort = avgjort
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

    /// ALT her er syntetisk (`example.com`, `EXAMPLE`, oppdiktede navn). Ikke lim inn noe fra serveren eller fra skjermbilder.
    /// Fixturen `naa-ekte-form.json` (AppCore-testene) speiler denne; en test sjekker at de gir samme skjerm.
    static func ekteFormData(nå: Date, kalender: Calendar) -> (Naa, [Traad]) {
        let min: TimeInterval = 60
        let lang = "https://git.example.com/eksempel/app/pull/4?ref=EXAMPLE0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        let naa = Naa(
            kort: [],
            avvik: [
                NaaAvvik(art: "venter", navn: "post-faktura-eksempel-7",
                         tekst: "Faktura-varsel fra leverandør <varsler+acct_EXAMPLE12345678abcdef@example.com> trenger svar",
                         ts: nå.addingTimeInterval(-(18 * min)), lenke: "shadow#/m/post-faktura-eksempel-7"),
                NaaAvvik(art: "venter", navn: "repo-utdatert-pr-eksempel-12",
                         tekst: "Avklar utdatert pull request \(lang)",
                         ts: nå.addingTimeInterval(-(95 * min)), lenke: "shadow#/m/repo-utdatert-pr-eksempel-12"),
                // Et langt, uknekkelig token som verken er e-post eller URL: blir stående i tittelen (layout-stresstest).
                NaaAvvik(art: "venter", navn: "docs-ref-eksempel-3",
                         tekst: "Avklar EKSEMPEL_REF_" + String(repeating: "a1b2c3d4e5", count: 9),
                         ts: nå.addingTimeInterval(-(240 * min)), lenke: "shadow#/m/docs-ref-eksempel-3"),
            ],
            kalender: [
                NaaKalenderHendelse(tittel: "Eksempeldag, ingen møter", kalender: nil,
                                    ts: kalender.startOfDay(for: nå), heleDagen: true),
                NaaKalenderHendelse(tittel: "Kvartalsgjennomgang og planlegging av eksempelprosjektet med hele teamet i Eksempel AS, Nordlys",
                                    kalender: nil, ts: nå.addingTimeInterval(110 * min), heleDagen: false),
            ]
        )
        return (naa, ekteFormTraader(nå: nå))
    }

    static func ekteFormTraader(nå: Date) -> [Traad] {
        let min: TimeInterval = 60
        return [
            Traad(id: "ekte-app", tittel: "kode:eksempel-app", sistAktiv: nå.addingTimeInterval(-6 * min),
                  holder: TraadHolder(type: .plattform, status: "working", aktiv: true)),
            Traad(id: "ekte-agent", tittel: "eksempel-agent", sistAktiv: nå.addingTimeInterval(-47 * min),
                  holder: TraadHolder(type: .plattform, status: "idle", aktiv: true)),
        ]
    }

    static func handlinger(_ h: DemoAvgjort.Handlinger) -> [NaaKort.Handling] {
        let avslaa = NaaKort.Handling(key: "deny", label: "Avslå")
        switch h {
        case .standard: return [.init(key: "approve", label: "Godkjenn"), avslaa]
        case .en: return [.init(key: "send", label: "✉️ Send"), avslaa]
        case .merketAvslaa: return [.init(key: "send", label: "Avslå"), avslaa]
        case .flere: return [.init(key: "send", label: "✉️ Send"), .init(key: "draft", label: "💾 Lagre utkast"), avslaa]
        }
    }

    private func data(nå: Date) -> (Naa, [Traad]) {
        if variant == .ekte { return Self.ekteFormData(nå: nå, kalender: kalender) }
        let min: TimeInterval = 60
        func treffer(_ time: Int, _ minutt: Int, etter: Date, ukedag: Int? = nil) -> Date {
            var komp = DateComponents(hour: time, minute: minutt)
            if let ukedag { komp.weekday = ukedag }
            return kalender.nextDate(after: etter, matching: komp, matchingPolicy: .nextTime) ?? etter
        }
        let trening = treffer(18, 0, etter: nå)
        let standup = treffer(8, 30, etter: nå, ukedag: 2)  // mandag
        let lang = avgjort?.langtKort == true
        let beskrivelse = lang ? DemoAvgjort.langTekst : "Armere alarmen"
        let mal = lang ? DemoAvgjort.langTekstForsteLinje : "Armere alarmen"
        let alarmAvgjort = avgjort?.erAvgjort("demo-alarm") == true
        let avvik: [NaaAvvik] = variant == .rolig ? [] : [
            NaaAvvik(art: "jobb", navn: "hermod-backup", tekst: "siste kjøring 03:10",
                     ts: treffer(3, 10, etter: nå.addingTimeInterval(-86_400)), lenke: nil),
            // Serveren sender også godkjenningen som «venter»-avvik (mission-feed.ts), med målet som tekst.
            // Den er samme sak som kortet og skal ikke telles to ganger.
            NaaAvvik(art: "venter", navn: "armere-alarmen", tekst: mal,
                     ts: nå.addingTimeInterval(-(3 * min + 12)), lenke: nil),
        ].filter { !(alarmAvgjort && $0.art == "venter") }
        let kort: [NaaKort] = variant == .rolig || alarmAvgjort ? [] : [
            NaaKort(id: "demo-alarm", name: "alarm", describe: beskrivelse, status: "pending",
                    expiresAt: nil, createdAt: nå.addingTimeInterval(-(3 * min + 12)), agent: nil,
                    threadKey: "kode:v10b:ajax-fix",
                    actions: Self.handlinger(avgjort?.handlinger ?? .standard))
        ]
        let naa = Naa(
            kort: kort, avvik: avvik,
            kalender: [NaaKalenderHendelse(tittel: "Trening", kalender: nil, ts: trening, heleDagen: false),
                       NaaKalenderHendelse(tittel: "Standup", kalender: nil, ts: standup, heleDagen: false)]
        )
        let traader = [
            Traad(id: "demo-huginn", tittel: "kode:huginn", sistAktiv: nå.addingTimeInterval(-8 * min),
                  holder: TraadHolder(type: .plattform, status: "working", aktiv: true)),
            Traad(id: "demo-cto", tittel: "cto", sistAktiv: nå.addingTimeInterval(-60 * min),
                  holder: TraadHolder(type: .plattform, status: "idle", aktiv: true)),
            // Kortet peker på tråden gjennom Telegram-nøkkelen (`live.telegram`), ikke gjennom tråd-id-en.
            Traad(id: "demo-ajax-fix", tittel: "kode:v10b:ajax-fix", sistAktiv: nå.addingTimeInterval(-125 * min),
                  holder: TraadHolder(type: .plattform, status: "idle", aktiv: true),
                  live: TraadLive(opptatt: false, telegram: ["kode:v10b:ajax-fix"])),
        ]
        return (naa, traader)
    }
}
