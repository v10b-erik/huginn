import Foundation

/// Visningsmodellen for «Nå»: det som venter på deg, og ingenting annet. Bygges deterministisk av
/// `Naa` + `[Traad]` + en injisert `nå` (ingenting her leser klokka), så alt testes uten UI og nettverk.
/// Viewene i App-målet tegner bare det denne strukturen sier; ingen logikk bor der.
public struct NaaSkjerm: Sendable, Equatable {
    public enum Tilstand: Sendable, Equatable {
        /// `antall` ting venter på Erik (godkjenninger + ventende missions).
        case krever(Int)
        /// Ingenting venter. En egen tilstand som alltid tegnes (identitet regel 3), ikke en tom variant.
        case rolig
    }

    /// Hva fargen skal bety (identitet regel 1). Ingen «pynt»-tone finnes.
    public enum Tone: Sendable, Equatable {
        /// Periwinkle: krever deg eller pågår.
        case aksent
        /// Rød: avvik, og bare det.
        case feil
        /// Grønn: i orden.
        case ok
        /// Dempet grå: alt annet.
        case dempet
    }

    /// Svaret på en godkjenning. Det `onSvar` i viewet får; selve API-kallet er neste oppgave.
    public struct Handling: Sendable, Equatable {
        public enum Valg: Sendable, Equatable { case godkjenn, avslaa }
        public var kortId: String
        public var valg: Valg
        /// Handlingsnøkkelen serveren ga (`approve`/`deny`); standard når kortet ikke lister dem.
        public var key: String

        public init(kortId: String, valg: Valg, key: String) {
            self.kortId = kortId
            self.valg = valg
            self.key = key
        }
    }

    /// Godkjenningsbrikken: et kort som venter på avgjørelse.
    public struct Godkjenning: Sendable, Equatable, Identifiable {
        public var id: String
        public var tittel: String
        /// Hvem som ber om det («Fra»), typisk trådnøkkelen.
        public var kilde: String?
        /// `true` = kilden er verifisert ren (vises som ordet «rent»). `nil` = ukjent, ingenting vises.
        public var kildeRen: Bool?
        /// Risikoklasse («Høyrisiko»). `nil` = serveren oppgir den ikke, og båndet utelates.
        public var klasse: String?
        public var opprettet: Date?
        public var godkjenn: Handling
        public var avslaa: Handling
    }

    /// En rad i en liste (avvik, ventende, tråder).
    public struct Rad: Sendable, Equatable, Identifiable {
        public var id: String
        public var tittel: String
        public var undertekst: String?
        /// Tilstanden som ORD («FEILET», «VENTER»), så fargen aldri står alene (regel 4).
        public var ord: String?
        /// Relativ tid («8 min»), når raden ikke har et tilstandsord.
        public var tid: String?
        public var tone: Tone
    }

    /// En av de tre tallkolonnene.
    public struct Kolonne: Sendable, Equatable, Identifiable {
        public var id: String
        public var tittel: String
        public var verdi: Int
        public var tone: Tone
        public var tekst: String
    }

    /// «NESTE»/«SÅ»-båndene.
    public struct Neste: Sendable, Equatable, Identifiable {
        public var etikett: String
        public var tittel: String
        public var tid: String
        public var id: String { etikett }
    }

    /// Flere enn dette skjules bak «+ N til»: «Nå» er ikke en tråd-liste.
    public static let maksTraader = 5

    public var topplinje: String
    public var plattformOk: Bool
    public var tilstand: Tilstand
    public var heroTittel: String
    public var heroUndertekst: String
    public var godkjenninger: [Godkjenning]
    /// Missions som venter på deg (`avvik` med art «venter»): de teller i heroen, så de må synes.
    public var venter: [Rad]
    public var kolonner: [Kolonne]
    public var avvik: [Rad]
    public var traader: [Rad]
    public var skjulteTraader: Int
    public var neste: [Neste]

    /// Tallet i heroen.
    public var antallKrever: Int {
        if case .krever(let n) = tilstand { return n }
        return 0
    }

    public init(naa: Naa, traader: [Traad], nå: Date, kalender: Calendar = .current) {
        let kalender = Tid.gregoriansk(kalender)
        topplinje = Tid.datolinje(nå: nå, kalender: kalender)

        // krever = kort som venter (status pending; manglende status regnes som pending, siden
        // `lagNaa()` bare sender ventende) + avvik med art «venter» som IKKE er samme sak som et kort.
        //
        // Serveren lager en mission for HVER frittstående godkjenning (mission-feed.ts `upsertFromApproval`),
        // og `lagNaa` sender den som avvik med art «venter»: samme sak står i både `kort` og `avvik`.
        // Et «venter»-avvik regnes som kortets dobbeltgjenger når (1) `approvalId` er lik kortets id, eller,
        // når avviket ikke bærer `approvalId` (serveren sender den ikke ennå), (2) `avvik.tekst` er lik første
        // linje av kortets `describe` (serverens `goal = firstLine(describe)`).
        //
        // KJENT HULL: en godkjenning som er et steg i en LØPENDE mission (kortets `threadKey` = `mission:…`)
        // blir missionens ventepunkt, og missionens `goal` er oppgavens mål, ikke kortets tekst. Den kan ikke
        // matches ennå og telles dobbelt til serveren sender `approvalId`.
        let ventendeKort = naa.kort.filter { $0.status == nil || $0.status == "pending" }
        let ventendeAvvik = naa.avvik.filter { $0.art == "venter" }
            .filter { a in !ventendeKort.contains { Self.samsvarer(avvik: a, kort: $0) } }
        let krever = ventendeKort.count + ventendeAvvik.count
        tilstand = krever > 0 ? .krever(krever) : .rolig

        // plattform ok = ingen avvik som sier at selve plattformen er syk.
        plattformOk = !naa.avvik.contains { $0.art == "tjeneste" || $0.art == "hjerteslag" }

        heroTittel = krever > 0 ? "Krever deg" : "Alt rolig"
        heroUndertekst = Self.heroUndertekst(kort: ventendeKort.count, venter: ventendeAvvik.count)

        godkjenninger = ventendeKort.map { kort in
            func nøkkel(_ ønsket: String) -> String {
                kort.actions?.first { $0.key == ønsket }?.key ?? ønsket
            }
            return Godkjenning(
                id: kort.id,
                tittel: kort.describe ?? kort.name ?? "Godkjenning",
                kilde: kort.threadKey ?? kort.agent,
                kildeRen: nil,
                klasse: nil,
                opprettet: kort.createdAt,
                godkjenn: Handling(kortId: kort.id, valg: .godkjenn, key: nøkkel("approve")),
                avslaa: Handling(kortId: kort.id, valg: .avslaa, key: nøkkel("deny"))
            )
        }

        venter = ventendeAvvik.map {
            Rad(id: $0.id, tittel: $0.navn, undertekst: $0.tekst, ord: "VENTER", tid: nil, tone: .aksent)
        }

        // avvik = alt som avviker unntatt det som bare venter på deg.
        let avvikene = naa.avvik.filter { $0.art != "venter" }
        avvik = avvikene.map {
            // Serverens «failed» er teknisk; ordet vi viser er norsk. En jobb som avviker har feilet.
            // Ukjent tekst bæres uendret som undertekst.
            let teknisk = $0.tekst.lowercased() == "failed"
            let feilet = teknisk || $0.art == "jobb"
            return Rad(
                id: $0.id, tittel: $0.navn, undertekst: teknisk ? $0.art : $0.tekst,
                ord: feilet ? "FEILET" : "AVVIK", tid: nil, tone: .feil
            )
        }

        let tråder = Self.traadRader(traader, kort: ventendeKort, nå: nå)
        self.traader = Array(tråder.rader.prefix(Self.maksTraader))
        skjulteTraader = max(0, tråder.rader.count - Self.maksTraader)

        neste = Self.nesteBand(naa, nå: nå, kalender: kalender)

        kolonner = [
            Self.avvikKolonne(avvikene, nå: nå, kalender: kalender),
            Self.traadKolonne(tråder),
            Self.idagKolonne(naa, nå: nå, kalender: kalender),
        ]
    }

    /// Alle feltene eksplisitt: brukes av forhåndsvisninger og av kilder som bygger skjermen selv.
    public init(
        topplinje: String, plattformOk: Bool, tilstand: Tilstand, heroTittel: String, heroUndertekst: String,
        godkjenninger: [Godkjenning], venter: [Rad], kolonner: [Kolonne], avvik: [Rad], traader: [Rad],
        skjulteTraader: Int, neste: [Neste]
    ) {
        self.topplinje = topplinje
        self.plattformOk = plattformOk
        self.tilstand = tilstand
        self.heroTittel = heroTittel
        self.heroUndertekst = heroUndertekst
        self.godkjenninger = godkjenninger
        self.venter = venter
        self.kolonner = kolonner
        self.avvik = avvik
        self.traader = traader
        self.skjulteTraader = skjulteTraader
        self.neste = neste
    }

    // MARK: - Hero

    /// Bevisst uten alder: undertekstene fryser mellom hentinger. Brikkens egen teller viser alderen levende.
    /// Heroens LCD stopper på 99; teksten sier alltid det faktiske tallet.
    private static func heroUndertekst(kort: Int, venter: Int) -> String {
        if kort == 0 && venter == 0 { return "Ingenting venter på deg" }
        var deler: [String] = []
        if kort + venter > 99 { deler.append("\(kort + venter) saker") }
        if kort == 1 {
            deler.append("Godkjenning")
        } else if kort > 1 {
            deler.append("\(kort) godkjenninger")
        }
        if venter > 0 { deler.append("\(venter) venter") }
        return deler.joined(separator: " · ")
    }

    /// Port av serverens `firstLine` (yggdrasil core/mission-feed.ts:48):
    /// `(s.split("\n").find((l) => l.trim()) ?? s).trim().slice(0, 200)`. Avviket som vises for en godkjenning har
    /// `tekst` = missionens `goal`, som er akkurat dette, så klienten må regne det ut likt for å kjenne igjen dobbeltgjengeren.
    /// To Swift-fallgruver: "\r\n" er ÉTT `Character` (derfor deler vi på unicode-skalarer, ikke tegn), og JS teller
    /// UTF-16-enheter i `slice` (derfor kutter vi på `utf16`, ikke på tegn).
    static func firstLine(_ tekst: String) -> String {
        let linjer = tekst.unicodeScalars
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String(String.UnicodeScalarView($0)) }
        let valgt = linjer.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? tekst
        let trimmet = valgt.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(decoding: Array(trimmet.utf16.prefix(200)), as: UTF16.self)
    }

    private static func samsvarer(avvik: NaaAvvik, kort: NaaKort) -> Bool {
        if let id = avvik.approvalId { return id == kort.id }
        guard let describe = kort.describe else { return false }
        return avvik.tekst == firstLine(describe)
    }

    // MARK: - Tråder

    private struct Traadutvalg {
        var rader: [Rad]
        var venter: Int
    }

    /// «I gang» = holderen er aktiv, eller tråden er opptatt akkurat nå (`live.opptatt`), eller den
    /// venter på deg. Parkerte og arkiverte tråder hører ikke hjemme på «Nå».
    ///
    /// «Venter» = tråden står stille på en avgjørelse fra deg: et ventende korts `threadKey` er en av trådens
    /// Telegram-nøkler (`live.telegram`) eller lik oppgavenøkkelen til en kode-tråd (`kode.oppgave.threadKey`),
    /// eller harnessen melder selv at den er blokkert. `blocked` er en av herdr-statusene
    /// `idle | working | blocked` (verdandi.ts, `Holder.status`; en blokkert agent regnes som aktiv der).
    /// Trådens egen `id` er en Claude Code-sesjons-id og sammenlignes ALDRI mot en `threadKey`.
    ///
    /// Raden viser ordet PÅGÅR (og aksent) når noe faktisk pågår (status «working», eller opptatt), ellers
    /// bare tiden i dempet når holderen står åpen («idle»): tilstanden er alltid et ord, ikke bare en lampe.
    private static func traadRader(_ alle: [Traad], kort: [NaaKort], nå: Date) -> Traadutvalg {
        let ikkeArkivert = alle.filter { $0.arkivert == nil }
        let kortNøkler = Set(kort.compactMap(\.threadKey))
        func venter(_ t: Traad) -> Bool {
            let nøkler = Set((t.live?.telegram ?? []) + [t.kode?.oppgave?.threadKey].compactMap { $0 })
            return !kortNøkler.isDisjoint(with: nøkler) || t.holder?.status?.lowercased() == "blocked"
        }
        func iGang(_ t: Traad) -> Bool {
            t.holder?.aktiv == true || t.live?.opptatt == true || venter(t)
        }
        let valgt = ikkeArkivert.filter(iGang).sorted { $0.sistAktiv > $1.sistAktiv }
        let rader = valgt.map { t -> Rad in
            if venter(t) {
                return Rad(id: t.id, tittel: t.tittel, undertekst: nil, ord: "VENTER", tid: nil, tone: .aksent)
            }
            let pågår = t.live?.opptatt == true || t.holder?.status?.lowercased() == "working"
            return Rad(
                id: t.id, tittel: t.tittel, undertekst: nil, ord: pågår ? "PÅGÅR" : nil,
                tid: Tid.relativ(fra: t.sistAktiv, til: nå), tone: pågår ? .aksent : .dempet
            )
        }
        return Traadutvalg(rader: rader, venter: valgt.filter(venter).count)
    }

    // MARK: - Kolonner

    private static func avvikKolonne(_ avvik: [NaaAvvik], nå: Date, kalender: Calendar) -> Kolonne {
        let tekst: String
        if avvik.isEmpty {
            tekst = "ingen"
        } else if let tidligst = avvik.compactMap(\.ts).min() {
            tekst = Tid.siden(tidligst, nå: nå, kalender: kalender)
        } else {
            tekst = avvik.count == 1 ? "se under" : "se listen"
        }
        return Kolonne(id: "avvik", tittel: "Avvik", verdi: avvik.count,
                       tone: avvik.isEmpty ? .dempet : .feil, tekst: tekst)
    }

    /// Tallet er tråder i gang; teksten sier hvor mange av dem som venter på deg. Ingen strek.
    private static func traadKolonne(_ t: Traadutvalg) -> Kolonne {
        Kolonne(
            id: "traader", tittel: "Tråder", verdi: t.rader.count,
            tone: .dempet, tekst: t.venter > 0 ? "\(t.venter) venter" : "ingen venter"
        )
    }

    /// Kalender- og påminnelsehendelser i dag (hele dagen, også de som har vært). Ingen strek.
    private static func idagKolonne(_ naa: Naa, nå: Date, kalender: Calendar) -> Kolonne {
        let idag = (naa.kalender.map(\.ts) + naa.paminnelser.map(\.ts)).filter {
            kalender.isDate($0, inSameDayAs: nå)
        }
        let kommende = idag.filter { $0 > nå }.min()
        let tekst: String
        if idag.isEmpty {
            tekst = "ingenting"
        } else if let kommende {
            tekst = "neste \(Tid.hhmm(kommende, kalender: kalender))"
        } else {
            tekst = "ferdig i dag"
        }
        return Kolonne(id: "idag", tittel: "I dag", verdi: idag.count, tone: .dempet, tekst: tekst)
    }

    // MARK: - Neste

    /// Kalender og påminnelser slått sammen, sortert på tid, bare fremtidige, maks to. Hele-dags-
    /// hendelser regnes som fremtidige så lenge dagen ikke er over.
    private static func nesteBand(_ naa: Naa, nå: Date, kalender: Calendar) -> [Neste] {
        struct Kandidat { var ts: Date; var tittel: String; var heleDagen: Bool }
        let alle =
            naa.kalender.map { Kandidat(ts: $0.ts, tittel: $0.tittel, heleDagen: $0.heleDagen == true) }
            + naa.paminnelser.map { Kandidat(ts: $0.ts, tittel: $0.tekst, heleDagen: false) }
        let fremtidige = alle.filter { k in
            if k.heleDagen {
                let slutt = kalender.date(byAdding: .day, value: 1, to: kalender.startOfDay(for: k.ts)) ?? k.ts
                return slutt > nå
            }
            return k.ts > nå
        }
        let sortert = fremtidige.sorted { $0.ts < $1.ts }
        return sortert.prefix(2).enumerated().map { i, k in
            Neste(
                etikett: i == 0 ? "Neste" : "Så", tittel: k.tittel,
                tid: Tid.dagOgTid(k.ts, nå: nå, heleDagen: k.heleDagen, kalender: kalender)
            )
        }
    }
}
