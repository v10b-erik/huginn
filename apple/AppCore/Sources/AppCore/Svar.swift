import Foundation

// Godkjenn/Avslå. Tre lag, alle uten UI:
//  - `Svarvalg`: hva som kan svares (utledet fra kortets handlinger).
//  - `Svar`: tilstandsmaskinen. Ingen nettverk og ingen autentisering inni; den sier bare hva som skal skje nå.
//  - `SvarTjeneste` (egen fil): orkestrerer maskinen mot `Autentisering`, nettverk og oppfriskning.
//
// Sikkerhetsreglene bor i maskinen, så de testes uten UI:
//  1. Godkjenn kan ikke nå `.sender` uten vellykket autentisering (`autentisert(.ok)` er eneste vei).
//  2. Single-flight: i `.autentiserer`/`.sender` ignoreres alle nye valg.
//  3. Et resultat for et annet forsøk (id) enn det som pågår ignoreres.
//  4. Ingen retry: en forespørsel uten svar blir `.usikker`, og neste forsendelse krever et nytt, bevisst valg
//     etter at brukeren har kvittert.

/// Ett av valgene på et kort. Serveren kjenner `deny` (Avslå) og kortets egne handlingsnøkler (typisk `approve`).
///
/// **Etiketten er aldri verbet.** Kortets etikett er serverstyrt tekst, og en etikett som «Avslå» på en utførende handling
/// ville fått en handling til å se ut som det trygge valget. Derfor heter Godkjenn alltid «Godkjenn» (`approve`) eller
/// `Godkjenn «<etikett>»` (enhver annen nøkkel), og Avslå heter alltid «Avslå» (`deny`), uansett hva serveren kaller dem.
public struct Svarvalg: Sendable, Equatable {
    public var key: String
    /// Kortets etikett for handlingen, renset (`rens`). Bare til bruk inne i anførselstegn etter «Godkjenn».
    public private(set) var etikett: String

    /// - Parameter label: kortets etikett slik serveren sendte den. Renses her, så alle veier inn er rene.
    public init(key: String, label: String) {
        self.key = key
        self.etikett = Self.rens(label, nøkkel: key)
    }

    /// Avslå er trygt: den utfører ingenting på serveren.
    public var erAvslag: Bool { key == "deny" }
    /// Alt som ikke er Avslå utfører noe og krever lokal autentisering først.
    public var krevAutentisering: Bool { !erAvslag }

    /// Det brukeren ser: knappen på brikken, arkets tittel og knapp, og begynnelsen på begrunnelsen til systemdialogen.
    public var label: String {
        if erAvslag { return "Avslå" }
        if key == "approve" { return "Godkjenn" }
        return "Godkjenn «\(etikett)»"
    }

    public static let avslaa = Svarvalg(key: "deny", label: "Avslå")

    private static let maksEtikett = 24

    /// Renser en serverstyrt etikett til noe som kan vises: fjerner kontroll- og formattegn (retningstegn U+202A–202E,
    /// U+2066–2069, U+200E/F, nullbredde U+200B/U+2060/U+FEFF), anførselstegn «», ledende emoji/symboler (Apple Color
    /// Emoji er en tredje skrift og bryter identitet regel 5), slår sammen mellomrom, og kutter til 24 tegn med «…».
    /// Blir den tom, brukes nøkkelen (renset og kuttet på samme måte).
    public static func rens(_ tekst: String, nøkkel: String) -> String {
        func grunn(_ s: String) -> String {
            let skalarer = s.unicodeScalars.filter { sk in
                switch sk.properties.generalCategory {
                case .control, .format: return false
                default: return sk != "«" && sk != "»"
                }
            }
            return String(String.UnicodeScalarView(skalarer)).split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        func erSymbol(_ sk: Unicode.Scalar) -> Bool {
            switch sk.properties.generalCategory {
            case .otherSymbol, .mathSymbol, .currencySymbol, .modifierSymbol, .enclosingMark: return true
            default: return (0xFE00...0xFE0F).contains(sk.value)  // variasjonsvelgere (✉️)
            }
        }
        func kutt(_ s: String) -> String {
            s.count > maksEtikett ? String(s.prefix(maksEtikett - 1)) + "…" : s
        }
        var s = grunn(tekst)
        while let f = s.unicodeScalars.first, erSymbol(f) || f == " " { s.unicodeScalars.removeFirst() }
        if !s.isEmpty { return kutt(s) }
        let n = kutt(grunn(nøkkel))
        return n.isEmpty ? "valg" : n
    }

    /// Godkjenn-valget for et kort, med kortets EGEN etikett (`approve` heter alltid «Godkjenn»). Appen tilbyr bare
    /// Godkjenn når det finnes nøyaktig ÉN handling som ikke er `deny`, eller kortet ikke har noen handlinger (binært
    /// kort: `approve`). Har kortet flere, eller bare `deny`, er svaret `nil`: ingen Godkjenn-vei finnes, og brukeren må
    /// svare i Telegram. Å velge «den første» ville sendt en handling brukeren aldri så navnet på.
    public static func godkjenn(actions: [NaaKort.Handling]?) -> Svarvalg? {
        let alle = actions ?? []
        let handlinger = alle.filter { $0.key != "deny" }
        guard handlinger.count <= 1 else { return nil }
        guard let a = handlinger.first else {
            // Ingen handlinger: binært kort. Bare `deny` oppgitt: ingenting å godkjenne (serveren ville avvist `approve`).
            return alle.isEmpty ? Svarvalg(key: "approve", label: "Godkjenn") : nil
        }
        return Svarvalg(key: a.key, label: a.label)
    }
}

/// Hvorfor et svar ikke ble registrert (eller kanskje ikke ble det). Meldinger er faste norske tekster: serverens
/// egen tekst vises aldri, og tokenet finnes ikke her.
public enum SvarFeil: Sendable, Equatable {
    case ugyldigKort
    case autentiseringUtilgjengelig
    case autentiseringFeilet
    case alleredeAvgjort(String?)
    case ukjentKort
    case ugyldigValg
    /// Serveren svarte med en annen avvisning (f.eks. 403). `status` er koden.
    case ikkeRegistrert(status: Int)
    /// 401.
    case kreverNyttToken
    /// En intern vakt stoppet forsendelsen. Ingenting ble sendt, og tilstanden kan forlates (`lukk`).
    case internFeil

    public var kreverNyttToken: Bool { self == .kreverNyttToken }

    /// ORD + melding (identitet regel 4: aldri farge alene).
    public var visning: SvarVisning {
        switch self {
        case .ugyldigKort:
            SvarVisning(ord: "IKKE SENDT", melding: "Kortet har en ugyldig id. Ingenting ble sendt.")
        case .autentiseringUtilgjengelig:
            SvarVisning(ord: "IKKE SENDT", melding: "Kan ikke bekrefte at det er deg på denne enheten. Sett opp Face ID, Touch ID eller kode. Ingenting ble sendt.")
        case .autentiseringFeilet:
            SvarVisning(ord: "IKKE SENDT", melding: "Bekreftelsen mislyktes. Ingenting ble sendt.")
        case .alleredeAvgjort(let tekst):
            // Serverens tekst brukes bare til å skille «allerede avgjort» fra «kunne ikke avgjøres».
            if let tekst, !tekst.lowercased().hasPrefix("kortet er allerede") {
                SvarVisning(ord: "IKKE AVGJORT", melding: "Serveren kunne ikke utføre handlingen. Oppdater for å se hva som står igjen.")
            } else if tekst?.lowercased().contains("avslått") == true {
                SvarVisning(ord: "KORTET ER ALLEREDE AVGJORT", melding: "Kortet er allerede avslått.")
            } else {
                SvarVisning(ord: "KORTET ER ALLEREDE AVGJORT", melding: "Kortet er allerede avgjort, så svaret ditt ble ikke brukt.")
            }
        case .ukjentKort:
            SvarVisning(ord: "UKJENT KORT", melding: "Serveren kjenner ikke kortet. Det er kanskje utløpt eller allerede håndtert.")
        case .ugyldigValg:
            SvarVisning(ord: "IKKE REGISTRERT", melding: "Serveren godtok ikke valget. Ingenting ble registrert.")
        case .ikkeRegistrert(let status):
            SvarVisning(ord: "IKKE REGISTRERT", melding: "Serveren avviste svaret (kode \(status)). Ingenting ble registrert.")
        case .internFeil:
            SvarVisning(ord: "IKKE SENDT", melding: "Noe gikk galt i appen. Ingenting ble sendt.")
        case .kreverNyttToken:
            SvarVisning(ord: "IKKE INNLOGGET", melding: "Enhetstokenet er ikke gyldig. Koble til på nytt. Ingenting ble registrert.")
        }
    }
}

/// Hvordan en feil eller usikkerhet står på skjermen.
public struct SvarVisning: Sendable, Equatable {
    public var ord: String
    public var melding: String
}

/// Resultatet av systemets autentisering.
public enum AutentiseringsUtfall: Sendable, Equatable {
    case ok
    /// Brukeren (eller systemet) avbrøt. Ingen feil: tilbake uten å sende.
    case avbrutt
    /// Ingen biometri og ingen kode å falle tilbake på.
    case utilgjengelig
    case feilet
}

/// Lokal autentisering (Face ID/Touch ID med kode som reserve) bak en protokoll, så flyten testes med en fake.
/// Ekte implementasjon (`LAContext`, `.deviceOwnerAuthentication`) bor i App-målet.
public protocol Autentisering: Sendable {
    /// - Parameter begrunnelse: teksten i systemdialogen. Inneholder aldri token.
    func autentiser(begrunnelse: String) async -> AutentiseringsUtfall
}

/// Tilstandsmaskinen for ett svar om gangen. Ren: ingen UI, ingen nettverk, ingen klokke. Kalleren utfører `Kommando`-en
/// hver overgang gir tilbake og melder utfallet.
public struct Svar: Sendable, Equatable {
    /// Det brukeren ber om: kortet (med hele teksten), risikoinformasjonen brikken viser, og valget (med kortets etikett).
    public struct Forespørsel: Sendable, Equatable {
        public var kortId: String
        /// Hele kortteksten (`describe`).
        public var tekst: String
        public var valg: Svarvalg
        /// «Fra», «rent» og «Klasse» slik brikken viser dem: de skal stå der man bestemmer seg.
        public var kilde: String?
        public var kildeRen: Bool?
        public var klasse: String?

        public init(kortId: String, tekst: String, valg: Svarvalg, kilde: String? = nil, kildeRen: Bool? = nil, klasse: String? = nil) {
            self.kortId = kortId
            self.tekst = tekst
            self.valg = valg
            self.kilde = kilde
            self.kildeRen = kildeRen
            self.klasse = klasse
        }

        /// Tegn som styrer lesretningen (U+202A–202E, U+2066–2069, U+200E/F). Fjernes fra alt som VISES (ikke fra
        /// modellen), så serverstyrt tekst ikke kan vri hvordan godkjenningen leses.
        private static let retningstegn: Set<Unicode.Scalar> = [
            "\u{202A}", "\u{202B}", "\u{202C}", "\u{202D}", "\u{202E}",
            "\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}", "\u{200E}", "\u{200F}",
        ]

        public static func rens(_ tekst: String) -> String {
            String(String.UnicodeScalarView(tekst.unicodeScalars.filter { !retningstegn.contains($0) }))
        }

        /// Tittelen (første linje med innhold) og resten av teksten. Tittel + rest er hele teksten.
        private var delt: (tittel: String, rest: String) {
            let t = Self.rens(tekst).replacingOccurrences(of: "\r\n", with: "\n")
            let linjer = t.unicodeScalars
                .split(omittingEmptySubsequences: false, whereSeparator: { CharacterSet.newlines.contains($0) })
                .map { String(String.UnicodeScalarView($0)) }
            guard let i = linjer.firstIndex(where: { !NaaSkjerm.maal($0).isEmpty }) else { return ("Godkjenning", "") }
            let rest = linjer[(i + 1)...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return (NaaSkjerm.maal(linjer[i]), rest)
        }

        /// Overskriften i bekreftelsen, VoiceOver og systemdialogen: første linje, uten retningstegn.
        public var forsteLinje: String { delt.tittel }
        /// Resten av kortteksten (kan være tom). Vises rullbar under overskriften.
        public var rest: String { delt.rest }

        /// «Hva skjer», konkret: Godkjenn utfører noe (kortets mål, eller handlingens etikett), Avslå utfører ingenting.
        public var konsekvens: String {
            if valg.erAvslag { return "Forespørselen forkastes. Ingenting utføres." }
            let hva = valg.key == "approve" ? Self.kutt(forsteLinje, 60) : valg.etikett
            return "«\(hva)» utføres så snart du godkjenner. Krever Face ID eller enhetskode."
        }

        private static func kutt(_ s: String, _ maks: Int) -> String {
            s.count > maks ? String(s.prefix(maks - 1)) + "…" : s
        }

        /// Teksten i systemets autentiseringsdialog: handlingens etikett og første linje, kuttet. Aldri token.
        public var begrunnelse: String {
            let maks = 80
            let linje = forsteLinje
            let kort = linje.count > maks ? String(linje.prefix(maks - 1)) + "…" : linje
            return "\(valg.label): \(kort)"
        }
    }

    /// Ett forsøk på å sende. `id` skiller et forsøk fra et eldre (eller et annet kort).
    public struct Forsøk: Sendable, Equatable {
        public var id: Int
        public var forespørsel: Forespørsel
        /// `true` bare etter `autentisert(.ok)`. `SvarTjeneste` sender aldri et Godkjenn-forsøk der dette er `false`.
        public var autentisert: Bool
    }

    public enum Tilstand: Sendable, Equatable {
        case ingen
        /// Bekreftelsen er oppe (hele teksten, hva som skjer). Ingenting er sendt eller spurt om ennå.
        case bekrefter(Forespørsel)
        /// Systemets dialog er oppe. Ingenting er sendt.
        case autentiserer(Forsøk)
        /// Forespørselen er ute. Begge knappene er av til svaret (eller feilen) kommer.
        case sender(Forsøk)
        /// Serveren registrerte avgjørelsen.
        case ferdig(Forespørsel)
        /// Forespørselen fikk ikke noe svar: vi vet ikke om den gikk gjennom. Kvitteres (`lukk`) før noe nytt.
        case usikker(Forespørsel)
        case feil(SvarFeil)
    }

    /// Hva kalleren skal gjøre nå.
    public enum Kommando: Sendable, Equatable {
        case ingenting
        case autentiser(Forsøk)
        case send(Forsøk)
        /// Hent `Nå` på nytt (én gang; ingenting sendes på nytt).
        case oppfrisk
    }

    /// Hva et forsøk endte med, sett fra nettverket.
    public enum Resultat: Sendable, Equatable {
        case utfall(SvarUtfall)
        case feil(TraadflataFeil)
    }

    public private(set) var tilstand: Tilstand = .ingen
    private var forrigeId = 0

    /// Hva som ble sendt, til meldingene: «Godkjenning», «Avslag», eller `Godkjenn «<etikett>»`.
    private static func hva(_ f: Forespørsel) -> String {
        if f.valg.erAvslag { return "Avslag" }
        return f.valg.key == "approve" ? "Godkjenning" : f.valg.label
    }

    /// Når en forespørsel ikke fikk svar og kortet fortsatt står der.
    public static func usikkerVisning(for f: Forespørsel) -> SvarVisning {
        SvarVisning(
            ord: "USIKKERT",
            melding: "\(hva(f)) er sendt, men vi fikk ingen bekreftelse. Trykk Oppdater: er kortet borte, gikk det gjennom. Står det igjen, kan du prøve på nytt."
        )
    }

    /// Når en forespørsel ikke fikk svar, men kortet allerede er borte fra «Nå».
    public static func usikkerBorteVisning(for f: Forespørsel) -> SvarVisning {
        SvarVisning(
            ord: "USIKKERT",
            melding: "\(hva(f)) er sendt, men vi fikk ingen bekreftelse. Kortet er borte fra «Nå», så det gikk trolig gjennom."
        )
    }

    public init() {}

    /// Står en forespørsel ute (eller venter på systemet)? Da er alle knapper av.
    public var opptatt: Bool {
        switch tilstand {
        case .autentiserer, .sender: true
        default: false
        }
    }

    /// Kan brukeren starte et nytt svar nå? Ikke mens noe pågår og ikke før en usikkerhet er kvittert.
    public var kanSvare: Bool {
        switch tilstand {
        case .autentiserer, .sender, .usikker: false
        default: true
        }
    }

    /// Hva et korts knapper gjør nå. Bare en forsendelse som pågår (eller venter på systemet) eller en usikkerhet som ikke
    /// er kvittert slår av ANDRE korts knapper; en kvittering (`.ferdig`) låser ingenting.
    public enum KortKnapper: Sendable, Equatable {
        case aktive
        /// Noe annet pågår: ingen knapper (ikke deaktiverte).
        case av
        case sender(Forespørsel)
        case usikker(Forespørsel)
    }

    public func knapper(for kortId: String) -> KortKnapper {
        switch tilstand {
        case .sender(let f): f.forespørsel.kortId == kortId ? .sender(f.forespørsel) : .av
        case .usikker(let f): f.kortId == kortId ? .usikker(f) : .av
        case .autentiserer: .av
        case .ingen, .bekrefter, .ferdig, .feil: .aktive
        }
    }

    /// Kortet (id) som pågår, når et gjør det: til «Sender …» på riktig brikke.
    public var kortISending: String? {
        if case .sender(let f) = tilstand { return f.forespørsel.kortId }
        return nil
    }

    // MARK: - overganger

    /// Godkjenn/Avslå ble trykket: åpne bekreftelsen. Ignoreres mens noe pågår eller en usikkerhet ikke er kvittert.
    /// En kort-id som ikke har serverens form stoppes her, før noe vises eller spørres om.
    public mutating func velg(_ f: Forespørsel) {
        guard kanSvare else { return }
        guard TraadflataKlient.erGyldigKortId(f.kortId) else {
            tilstand = .feil(.ugyldigKort)
            return
        }
        tilstand = .bekrefter(f)
    }

    /// Knappen i bekreftelsen. Godkjenn går til autentisering, Avslå rett til forsendelse (trygt). Dobbelttrykk gir ingenting:
    /// bare `.bekrefter` kan bekreftes.
    public mutating func bekreft() -> Kommando {
        guard case .bekrefter(let f) = tilstand else { return .ingenting }
        forrigeId += 1
        let forsøk = Forsøk(id: forrigeId, forespørsel: f, autentisert: false)
        if f.valg.krevAutentisering {
            tilstand = .autentiserer(forsøk)
            return .autentiser(forsøk)
        }
        tilstand = .sender(forsøk)
        return .send(forsøk)
    }

    /// Systemets svar. Eneste vei fra `.autentiserer` til `.sender`, og bare ved `.ok`. Avbrutt, utilgjengelig og
    /// feilet sender ingenting. Et svar for et annet forsøk ignoreres.
    public mutating func autentisert(id: Int, utfall: AutentiseringsUtfall) -> Kommando {
        guard case .autentiserer(var f) = tilstand, f.id == id else { return .ingenting }
        switch utfall {
        case .ok:
            f.autentisert = true
            tilstand = .sender(f)
            return .send(f)
        case .avbrutt:
            tilstand = .ingen
        case .utilgjengelig:
            tilstand = .feil(.autentiseringUtilgjengelig)
        case .feilet:
            tilstand = .feil(.autentiseringFeilet)
        }
        return .ingenting
    }

    /// Nettverkets svar. Et resultat for et annet forsøk (annen id, annet kort) eller utenfor `.sender` ignoreres.
    public mutating func resultat(id: Int, _ r: Resultat) -> Kommando {
        guard case .sender(let f) = tilstand, f.id == id else { return .ingenting }
        switch r {
        case .utfall(.avgjort):
            tilstand = .ferdig(f.forespørsel)
            return .oppfrisk
        case .utfall(.alleredeAvgjort(let tekst)):
            tilstand = .feil(.alleredeAvgjort(tekst))
            return .oppfrisk
        case .utfall(.ukjentKort):
            tilstand = .feil(.ukjentKort)
            return .oppfrisk
        case .utfall(.ugyldigValg):
            tilstand = .feil(.ugyldigValg)
            return .ingenting
        case .feil(.ikkeInnlogget):
            tilstand = .feil(.kreverNyttToken)
            return .ingenting
        case .feil(.ugyldigKortId):
            tilstand = .feil(.ugyldigKort)
            return .ingenting
        case .feil(.http(let status, _)) where (400..<500).contains(status):
            // Serveren svarte og avviste: den har ikke rørt kortet.
            tilstand = .feil(.ikkeRegistrert(status: status))
            return .ingenting
        case .feil:
            // Nettverk, tidsavbrudd, 5xx, svar som ikke er HTTP: vi vet ikke om det gikk gjennom. Én henting av `Nå`
            // (kortet er borte hvis det gjorde), aldri en ny forsendelse.
            tilstand = .usikker(f.forespørsel)
            return .oppfrisk
        }
    }

    /// En intern vakt stoppet en forsendelse som ikke skulle skjedd. Tilstanden blir en feil som kan lukkes, ikke en
    /// `.sender` ingen får forlatt. Gjelder bare det forsøket som pågår.
    public mutating func stopp(id: Int) {
        guard case .sender(let f) = tilstand, f.id == id else { return }
        tilstand = .feil(.internFeil)
    }

    /// Lukker bekreftelsen, kvitterer en feil/usikkerhet/ferdig, eller avbryter autentiseringen (et senere svar fra
    /// systemet er da for et gammelt forsøk og ignoreres). Gjør ingenting mens en forespørsel er ute: den kan ikke
    /// kalles tilbake, og skjermen skal ikke late som.
    public mutating func lukk() {
        if case .sender = tilstand { return }
        tilstand = .ingen
    }
}
