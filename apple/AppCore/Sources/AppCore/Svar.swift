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
public struct Svarvalg: Sendable, Equatable {
    public var key: String
    public var label: String

    public init(key: String, label: String) {
        self.key = key
        self.label = label
    }

    /// Avslå er trygt: den utfører ingenting på serveren.
    public var erAvslag: Bool { key == "deny" }
    /// Alt som ikke er Avslå utfører noe og krever lokal autentisering først.
    public var krevAutentisering: Bool { !erAvslag }

    public static let avslaa = Svarvalg(key: "deny", label: "Avslå")

    /// Godkjenn-valget for et kort: `approve` når kortet har den (eller ingen handlinger: binært kort), ellers kortets
    /// første handling som ikke er `deny` (serveren avviser `approve` med 400 når kortet har andre handlinger).
    /// Aldri `deny`: Godkjenn kan ikke ende som et avslag, og Avslå kan ikke ende som en handling.
    public static func godkjenn(actions: [NaaKort.Handling]?) -> Svarvalg {
        let handlinger = (actions ?? []).filter { $0.key != "deny" }
        if let a = handlinger.first(where: { $0.key == "approve" }) ?? handlinger.first {
            return Svarvalg(key: a.key, label: a.label.isEmpty ? "Godkjenn" : a.label)
        }
        return Svarvalg(key: "approve", label: "Godkjenn")
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
    /// Det brukeren ber om: kortet (med hele teksten) og valget.
    public struct Forespørsel: Sendable, Equatable {
        public var kortId: String
        /// Hele kortteksten (`describe`), vist rullbar i bekreftelsen.
        public var tekst: String
        public var valg: Svarvalg

        public init(kortId: String, tekst: String, valg: Svarvalg) {
            self.kortId = kortId
            self.tekst = tekst
            self.valg = valg
        }

        /// Første linje med innhold, rensket for usynlige tegn. Til tittel, VoiceOver og systemdialogen.
        public var forsteLinje: String {
            let l = NaaSkjerm.maal(tekst)
            return l.isEmpty ? "Godkjenning" : l
        }

        /// Teksten i systemets autentiseringsdialog: handlingen og første linje, kuttet. Aldri token.
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

    /// Når en forespørsel ikke fikk svar. Samme tekst på skjermen og i testen.
    public static let usikkerVisning = SvarVisning(
        ord: "USIKKERT",
        melding: "Usikkert om svaret ble registrert. Kortet er borte hvis det gikk gjennom."
    )

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

    /// Lukker bekreftelsen, kvitterer en feil/usikkerhet/ferdig, eller avbryter autentiseringen (et senere svar fra
    /// systemet er da for et gammelt forsøk og ignoreres). Gjør ingenting mens en forespørsel er ute: den kan ikke
    /// kalles tilbake, og skjermen skal ikke late som.
    public mutating func lukk() {
        if case .sender = tilstand { return }
        tilstand = .ingen
    }
}
