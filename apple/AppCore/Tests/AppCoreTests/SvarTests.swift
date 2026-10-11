import Foundation
import Testing
@testable import AppCore

/// Tilstandsmaskinen `Svar`: hvem som kommer til `.sender`, og hva som ignoreres.
@Suite struct SvarTests {
    private func forespørsel(_ valg: Svarvalg = Svarvalg(key: "approve", label: "Godkjenn"), id: String = "demo-alarm", tekst: String = "Armere alarmen\n\nDetaljer her") -> Svar.Forespørsel {
        Svar.Forespørsel(kortId: id, tekst: tekst, valg: valg)
    }

    private let godkjenn = Svarvalg(key: "approve", label: "Godkjenn")

    private func ibekreftelse(_ valg: Svarvalg) -> Svar {
        var s = Svar()
        s.velg(forespørsel(valg))
        return s
    }

    // MARK: - valg

    @Test func godkjennOgAvslåSkillerPåAutentisering() {
        #expect(godkjenn.krevAutentisering && !godkjenn.erAvslag)
        #expect(Svarvalg.avslaa.erAvslag && !Svarvalg.avslaa.krevAutentisering)
        #expect(Svarvalg(key: "deploy", label: "Utfør").krevAutentisering, "alle handlinger som ikke er deny utfører noe")
    }

    @Test func valgUtledesFraKortetsHandlinger() {
        #expect(Svarvalg.godkjenn(actions: nil) == godkjenn, "binært kort: approve")
        #expect(Svarvalg.godkjenn(actions: []) == godkjenn)
        let a = NaaKort.Handling(key: "approve", label: "Godkjenn"), d = NaaKort.Handling(key: "deny", label: "Avslå")
        #expect(Svarvalg.godkjenn(actions: [d, a])?.key == "approve")
        let u = NaaKort.Handling(key: "deploy", label: "Rull ut")
        #expect(Svarvalg.godkjenn(actions: [u, d]) == Svarvalg(key: "deploy", label: "Rull ut"), "én egen handling: dens etikett følger med")
        #expect(Svarvalg.godkjenn(actions: [u, d])?.label == "Godkjenn «Rull ut»")
        #expect(Svarvalg.godkjenn(actions: [d]) == nil, "bare deny: ingenting å godkjenne (K1)")
        #expect(Svarvalg.godkjenn(actions: nil)?.key == "approve" && Svarvalg.godkjenn(actions: [])?.key == "approve", "binært kort: approve")
        let aMedEmoji = NaaKort.Handling(key: "approve", label: "✅ Ja takk")
        #expect(Svarvalg.godkjenn(actions: [aMedEmoji, d])?.label == "Godkjenn", "approve heter alltid Godkjenn")
    }

    // MARK: - R2: hvilken handling

    private func kort(_ actions: [NaaKort.Handling]?) -> NaaKort {
        NaaKort(id: "kort-0001", name: nil, describe: "Send eposten\n\nTil kunde@example.com", status: "pending", expiresAt: nil,
                createdAt: nil, agent: nil, threadKey: "kode:eksempel", actions: actions)
    }

    private func skjermMed(_ k: NaaKort) -> NaaSkjerm.Godkjenning {
        NaaSkjerm(naa: Naa(kort: [k]), traader: [], nå: Date(timeIntervalSince1970: 1_760_000_000)).godkjenninger[0]
    }

    @Test func énEgenHandlingBærerSinEtikettHeltTilForespørselenOgBegrunnelsen() throws {
        let g = skjermMed(kort([.init(key: "send", label: "✉️ Send"), .init(key: "deny", label: "Avslå")]))
        let h = try #require(g.godkjenn)
        #expect(h.key == "send" && h.label == "Godkjenn «Send»" && h.etikett == "Send", "emoji fjernet, aldri etiketten alene")
        let f = try #require(g.forespørsel(for: h))
        #expect(f.valg == Svarvalg(key: "send", label: "✉️ Send"))
        #expect(f.valg.krevAutentisering)
        #expect(f.begrunnelse == "Godkjenn «Send»: Send eposten")
        #expect(f.konsekvens == "«Send» utføres så snart du godkjenner. Krever Face ID eller enhetskode.")
        #expect(f.kilde == "kode:eksempel", "risikoinformasjonen følger med til bekreftelsen")
    }

    @Test func flereHandlingerGirIngenGodkjennVeiIModellenOgIngenForespørsel() throws {
        let g = skjermMed(kort([.init(key: "send", label: "✉️ Send"), .init(key: "draft", label: "💾 Lagre utkast"), .init(key: "deny", label: "Avslå")]))
        #expect(g.godkjenn == nil)
        // Heller ikke ved å lage handlingen for hånd: nøkkelen er ikke kortets egen Godkjenn.
        for key in ["send", "draft", "approve"] {
            #expect(g.forespørsel(for: NaaSkjerm.Handling(kortId: g.id, valg: .godkjenn, key: key)) == nil)
        }
        // Avslå virker som vanlig.
        let avslag = try #require(g.forespørsel(for: g.avslaa))
        #expect(avslag.valg == .avslaa && !avslag.valg.krevAutentisering)
        // (Tilstandsmaskinen har ingenting å bekrefte: det finnes ingen forespørsel å gi den. `GodkjennTests` dekker flyten.)
    }

    @Test func godkjennMedFremmedNøkkelEllerAnnetKortGirIngenForespørsel() {
        let g = skjermMed(kort(nil))
        #expect(g.forespørsel(for: NaaSkjerm.Handling(kortId: g.id, valg: .godkjenn, key: "deploy")) == nil)
        #expect(g.forespørsel(for: NaaSkjerm.Handling(kortId: "annet-kort", valg: .godkjenn, key: "approve")) == nil)
        #expect(g.forespørsel(for: NaaSkjerm.Handling(kortId: g.id, valg: .godkjenn, key: "approve")) != nil)
    }

    // MARK: - godkjenn krever autentisering

    @Test func godkjennGårViaAutentisering_ikkeRettTilSending() {
        var s = ibekreftelse(godkjenn)
        guard case .autentiser(let f) = s.bekreft() else { Issue.record("ventet autentiser"); return }
        guard case .autentiserer = s.tilstand else { Issue.record("ventet .autentiserer"); return }
        #expect(!f.autentisert)
        #expect(s.kortISending == nil)
    }

    @Test func godkjennKommerBareTilSenderEtterOk() {
        var s = ibekreftelse(godkjenn)
        guard case .autentiser(let f) = s.bekreft() else { return }
        let k = s.autentisert(id: f.id, utfall: .ok)
        guard case .send(let sendt) = k else { Issue.record("ventet send"); return }
        #expect(sendt.autentisert)
        guard case .sender = s.tilstand else { Issue.record("ventet .sender"); return }
    }

    @Test(arguments: [AutentiseringsUtfall.avbrutt, .utilgjengelig, .feilet])
    func autentiseringSomIkkeLykkesSenderIngenting(utfall: AutentiseringsUtfall) {
        var s = ibekreftelse(godkjenn)
        guard case .autentiser(let f) = s.bekreft() else { return }
        #expect(s.autentisert(id: f.id, utfall: utfall) == .ingenting)
        if case .sender = s.tilstand { Issue.record("kom til .sender uten autentisering") }
        switch utfall {
        case .avbrutt: #expect(s.tilstand == .ingen)
        case .utilgjengelig: #expect(s.tilstand == .feil(.autentiseringUtilgjengelig))
        default: #expect(s.tilstand == .feil(.autentiseringFeilet))
        }
        #expect(s.kanSvare, "du kan prøve igjen")
    }

    @Test func autentiseringsSvarForGammeltForsøkIgnoreres() {
        var s = ibekreftelse(godkjenn)
        guard case .autentiser(let gammel) = s.bekreft() else { return }
        s.lukk()  // brukeren avbryter mens systemdialogen er oppe
        #expect(s.tilstand == .ingen)
        s.velg(forespørsel(godkjenn))
        guard case .autentiser(let ny) = s.bekreft() else { return }
        #expect(ny.id != gammel.id)
        // Det gamle forsøkets «ok» kommer for sent og skal ikke sende noe.
        #expect(s.autentisert(id: gammel.id, utfall: .ok) == .ingenting)
        guard case .autentiserer(let f) = s.tilstand else { Issue.record("skulle fortsatt vente"); return }
        #expect(f.id == ny.id)
    }

    @Test func autentiseringsSvarUtenForsøkSenderIngenting() {
        var s = Svar()
        #expect(s.autentisert(id: 1, utfall: .ok) == .ingenting)
        #expect(s.tilstand == .ingen)
        s.velg(forespørsel(godkjenn))
        #expect(s.autentisert(id: 1, utfall: .ok) == .ingenting, "bekreftelsen er ikke bekreftet ennå")
        #expect(s.tilstand == .bekrefter(forespørsel(godkjenn)))
    }

    @Test func ingenVeiTilSenderForGodkjennUtenOk() {
        // Prøver alle overganger fra alle tilstander og sjekker at `.send` for Godkjenn alltid har `autentisert`.
        var s = ibekreftelse(godkjenn)
        var kommandoer: [Svar.Kommando] = []
        kommandoer.append(s.bekreft())
        kommandoer.append(s.bekreft())
        kommandoer.append(s.resultat(id: 1, .utfall(.avgjort)))
        kommandoer.append(s.autentisert(id: 2, utfall: .ok))
        kommandoer.append(s.autentisert(id: 1, utfall: .feilet))
        kommandoer.append(s.autentisert(id: 1, utfall: .ok))
        for k in kommandoer {
            if case .send(let f) = k { #expect(f.autentisert || !f.forespørsel.valg.krevAutentisering) }
        }
    }

    // MARK: - avslå

    @Test func avslåKanSendesUtenAutentiseringMenTrengerBekreftelse() {
        var s = Svar()
        #expect(s.bekreft() == .ingenting, "uten bekreftelse skjer ingenting")
        s.velg(forespørsel(.avslaa))
        guard case .bekrefter = s.tilstand else { Issue.record("Avslå trenger bekreftelse"); return }
        guard case .send(let f) = s.bekreft() else { Issue.record("ventet send"); return }
        #expect(f.forespørsel.valg.erAvslag)
        guard case .sender = s.tilstand else { Issue.record("ventet .sender"); return }
    }

    // MARK: - single-flight

    @Test func dobbelttrykkIBekreftelsenGirEnForsendelse() {
        var s = ibekreftelse(.avslaa)
        var antall = 0
        for _ in 0..<5 { if case .send = s.bekreft() { antall += 1 } }
        #expect(antall == 1)
    }

    @Test func nyttValgMensDetSendesIgnoreres() {
        var s = ibekreftelse(.avslaa)
        guard case .send(let f) = s.bekreft() else { return }
        s.velg(forespørsel(godkjenn, id: "annet-kort-1"))
        s.velg(forespørsel(.avslaa))
        guard case .sender(let nå) = s.tilstand else { Issue.record("skulle fortsatt sende"); return }
        #expect(nå == f)
        #expect(!s.kanSvare && s.opptatt)
        #expect(s.kortISending == "demo-alarm")
    }

    @Test func nyttValgMensViVenterPåSystemdialogenIgnoreres() {
        var s = ibekreftelse(godkjenn)
        _ = s.bekreft()
        s.velg(forespørsel(.avslaa, id: "annet-kort-1"))
        guard case .autentiserer = s.tilstand else { Issue.record("skulle fortsatt vente"); return }
    }

    @Test func lukkGjørIngentingMensDetSendes() {
        var s = ibekreftelse(.avslaa)
        _ = s.bekreft()
        s.lukk()
        guard case .sender = s.tilstand else { Issue.record("en forespørsel som er ute kan ikke kalles tilbake"); return }
    }

    @Test func resultatForGammeltForsøkEllerAnnetKortIgnoreres() {
        var s = ibekreftelse(.avslaa)
        guard case .send(let f) = s.bekreft() else { return }
        #expect(s.resultat(id: f.id + 1, .utfall(.avgjort)) == .ingenting)
        #expect(s.resultat(id: f.id - 1, .utfall(.avgjort)) == .ingenting)
        guard case .sender = s.tilstand else { Issue.record("skulle fortsatt sende"); return }
        #expect(s.resultat(id: f.id, .utfall(.avgjort)) == .oppfrisk)
        #expect(s.tilstand == .ferdig(f.forespørsel))
        // Og når det er over, gjør et etternølende resultat ingenting.
        #expect(s.resultat(id: f.id, .feil(.nettverk("x"))) == .ingenting)
        #expect(s.tilstand == .ferdig(f.forespørsel))
    }

    @Test func resultatMedForsøksIdFraEtAnnetKortIgnoreres() {
        var s = ibekreftelse(.avslaa)
        guard case .send(let a) = s.bekreft() else { return }
        _ = s.resultat(id: a.id, .utfall(.avgjort))
        s.lukk()
        s.velg(forespørsel(.avslaa, id: "kort-nummer-to"))
        guard case .send(let b) = s.bekreft() else { return }
        #expect(s.resultat(id: a.id, .utfall(.avgjort)) == .ingenting, "svaret for kort 1 gjelder ikke kort 2")
        guard case .sender(let nå) = s.tilstand else { Issue.record("kort 2 skulle fortsatt sende"); return }
        #expect(nå.forespørsel.kortId == "kort-nummer-to" && nå.id == b.id)
    }

    // MARK: - utfall

    @Test func avgjortGirFerdigOgEnOppfriskning() {
        var s = ibekreftelse(.avslaa)
        guard case .send(let f) = s.bekreft() else { return }
        #expect(s.resultat(id: f.id, .utfall(.avgjort)) == .oppfrisk)
        #expect(s.tilstand == .ferdig(f.forespørsel))
        #expect(s.kanSvare)
    }

    @Test func alleredeAvgjortOgUkjentKortOppfrisker() {
        for (utfall, forventet) in [
            (SvarUtfall.alleredeAvgjort("kortet er allerede avslått"), SvarFeil.alleredeAvgjort("kortet er allerede avslått")),
            (.ukjentKort, .ukjentKort),
        ] {
            var s = ibekreftelse(.avslaa)
            guard case .send(let f) = s.bekreft() else { return }
            #expect(s.resultat(id: f.id, .utfall(utfall)) == .oppfrisk)
            #expect(s.tilstand == .feil(forventet))
        }
    }

    @Test func ugyldigValgGirFeilUtenOppfriskning() {
        var s = ibekreftelse(.avslaa)
        guard case .send(let f) = s.bekreft() else { return }
        #expect(s.resultat(id: f.id, .utfall(.ugyldigValg)) == .ingenting)
        #expect(s.tilstand == .feil(.ugyldigValg))
    }

    @Test func ikkeInnloggetGirKreverNyttToken() {
        var s = ibekreftelse(.avslaa)
        guard case .send(let f) = s.bekreft() else { return }
        #expect(s.resultat(id: f.id, .feil(.ikkeInnlogget)) == .ingenting)
        #expect(s.tilstand == .feil(.kreverNyttToken))
        #expect(SvarFeil.kreverNyttToken.kreverNyttToken)
    }

    @Test(arguments: [TraadflataFeil.nettverk("tidsavbrudd"), .ugyldigSvar, .http(status: 500, melding: nil), .http(status: 502, melding: nil), .http(status: 504, melding: nil)])
    func svarUtenSvarErUsikkertOgOppfriskerBareEnGang(feil: TraadflataFeil) {
        var s = ibekreftelse(.avslaa)
        guard case .send(let f) = s.bekreft() else { return }
        #expect(s.resultat(id: f.id, .feil(feil)) == .oppfrisk, "ny HENTING, aldri ny forsendelse")
        #expect(s.tilstand == .usikker(f.forespørsel))
        // En ny forsendelse krever kvittering først.
        s.velg(forespørsel(.avslaa))
        #expect(s.tilstand == .usikker(f.forespørsel), "usikkerhet må kvitteres før noe nytt")
        #expect(!s.kanSvare)
        #expect(s.bekreft() == .ingenting)
        s.lukk()
        #expect(s.tilstand == .ingen && s.kanSvare)
    }

    @Test func serverensAvvisningUnder500ErIkkeRegistrert() {
        var s = ibekreftelse(.avslaa)
        guard case .send(let f) = s.bekreft() else { return }
        #expect(s.resultat(id: f.id, .feil(.http(status: 403, melding: "annet opphav"))) == .ingenting)
        #expect(s.tilstand == .feil(.ikkeRegistrert(status: 403)))
    }

    @Test func ugyldigKortIdStoppesFørBekreftelsen() {
        for id in ["", "abc", "../naa", "kort 1", "abc/def123"] {
            var s = Svar()
            s.velg(forespørsel(godkjenn, id: id))
            #expect(s.tilstand == .feil(.ugyldigKort))
            #expect(s.bekreft() == .ingenting)
        }
    }

    // MARK: - meldinger

    @Test func norskeMeldingerMedOrd() {
        #expect(SvarFeil.alleredeAvgjort("kortet er allerede avslått").visning
            == SvarVisning(ord: "KORTET ER ALLEREDE AVGJORT", melding: "Kortet er allerede avslått."))
        #expect(SvarFeil.alleredeAvgjort("kortet er allerede avgjort").visning.melding.contains("allerede avgjort"))
        #expect(SvarFeil.alleredeAvgjort(nil).visning.ord == "KORTET ER ALLEREDE AVGJORT")
        #expect(SvarFeil.alleredeAvgjort("effector gone").visning.ord == "IKKE AVGJORT", "409 for noe annet enn allerede avgjort")
        #expect(!SvarFeil.alleredeAvgjort("effector gone").visning.melding.contains("effector"), "serverens tekst vises aldri")
        #expect(SvarFeil.ukjentKort.visning.ord == "UKJENT KORT")
        #expect(SvarFeil.ugyldigValg.visning.ord == "IKKE REGISTRERT")
        #expect(SvarFeil.ikkeRegistrert(status: 403).visning.melding.contains("403"))
        #expect(SvarFeil.autentiseringUtilgjengelig.visning.melding.contains("Ingenting ble sendt"))
        #expect(SvarFeil.kreverNyttToken.visning.ord == "IKKE INNLOGGET")
        let f = forespørsel(Svarvalg(key: "send", label: "✉️ Send"))
        #expect(Svar.usikkerVisning(for: f).ord == "USIKKERT")
        #expect(Svar.usikkerVisning(for: f).melding == "Godkjenn «Send» er sendt, men vi fikk ingen bekreftelse. Trykk Oppdater: er kortet borte, gikk det gjennom. Står det igjen, kan du prøve på nytt.")
        #expect(Svar.usikkerVisning(for: forespørsel()).melding.hasPrefix("Godkjenning er sendt, men vi fikk ingen bekreftelse."))
        #expect(Svar.usikkerVisning(for: forespørsel(.avslaa)).melding.hasPrefix("Avslag er sendt"))
        #expect(Svar.usikkerBorteVisning(for: f).melding.contains("borte fra «Nå»"))
    }

    @Test func begrunnelsenBærerFørsteLinjeOgAldriMer() {
        let f = forespørsel(godkjenn, tekst: "\n  Rull ut eksempeltjenesten  \nHemmelig andre linje")
        #expect(f.forsteLinje == "Rull ut eksempeltjenesten")
        #expect(f.begrunnelse == "Godkjenn: Rull ut eksempeltjenesten")
        #expect(f.rest == "Hemmelig andre linje", "tittel + rest er hele teksten")
        let lang = forespørsel(godkjenn, tekst: String(repeating: "x", count: 300))
        #expect(lang.begrunnelse.count <= "Godkjenn: ".count + 80)
        #expect(lang.begrunnelse.hasSuffix("…"))
        #expect(forespørsel(godkjenn, tekst: "   \n ").forsteLinje == "Godkjenning")
    }

    // MARK: - S2 og S3

    @Test func sikkerhetsstoppGirEnFeilSomKanForlates() {
        var s = ibekreftelse(.avslaa)
        guard case .send(let f) = s.bekreft() else { return }
        s.stopp(id: f.id + 1)
        guard case .sender = s.tilstand else { Issue.record("stopp for et annet forsøk skal ignoreres"); return }
        s.stopp(id: f.id)
        #expect(s.tilstand == .feil(.internFeil))
        #expect(SvarFeil.internFeil.visning.melding.contains("Ingenting ble sendt"))
        #expect(s.kanSvare && !s.opptatt)
        s.lukk()
        #expect(s.tilstand == .ingen)
    }

    @Test func retningstegnFjernesFraVisningenMenIkkeFraModellen() {
        let farlig = "Godkjenn\u{202E}gnirts\u{2066}x\u{2069}\u{200F}\n\nRest\u{200E}en"
        let f = forespørsel(godkjenn, tekst: farlig)
        #expect(f.tekst == farlig, "modellen er uendret")
        #expect(f.forsteLinje == "Godkjenngnirtsx")
        #expect(f.rest == "Resten")
        #expect(f.begrunnelse == "Godkjenn: Godkjenngnirtsx")
        for c in ["\u{202A}", "\u{202B}", "\u{202C}", "\u{202D}", "\u{202E}", "\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}", "\u{200E}", "\u{200F}"] {
            #expect(!Svar.Forespørsel.rens("a\(c)b").contains(c))
        }
        #expect(NaaSkjerm.Godkjenning.forsteLinje("A\u{202E}B") == "AB")
    }

    @Test func tittelOgRestMedCrlfOgTomTekst() {
        let f = forespørsel(godkjenn, tekst: "\r\n Tittel \r\n\r\nLinje 1\r\nLinje 2\r\n")
        #expect(f.forsteLinje == "Tittel")
        #expect(f.rest.hasPrefix("Linje 1") && f.rest.hasSuffix("Linje 2"))
        #expect(forespørsel(godkjenn, tekst: "Bare tittel").rest.isEmpty)
    }

    // MARK: - E1: etiketten er aldri verbet

    /// Det FORSØKTE EKSEMPELET: en utførende handling merket «Avslå».
    @Test func handlingMerketAvslåPresenteresSomGodkjennOgSenderSendNøkkelen() throws {
        let g = skjermMed(kort([.init(key: "send", label: "Avslå"), .init(key: "deny", label: "Avslå")]))
        let h = try #require(g.godkjenn)
        #expect(h.label == "Godkjenn «Avslå»", "etiketten står alltid etter Godkjenn, i anførselstegn")
        #expect(h.label != "Avslå" && g.avslaa.label == "Avslå")
        #expect(h.key == "send" && g.avslaa.key == "deny")
        let f = try #require(g.forespørsel(for: h))
        #expect(f.valg.label == "Godkjenn «Avslå»" && f.valg.key == "send" && f.valg.krevAutentisering && !f.valg.erAvslag)
        #expect(f.begrunnelse == "Godkjenn «Avslå»: Send eposten")
        #expect(f.konsekvens.hasPrefix("«Avslå» utføres så snart du godkjenner."))
        #expect(Svar.usikkerVisning(for: f).melding.hasPrefix("Godkjenn «Avslå» er sendt"))
        // Og Avslå er alltid deny og alltid «Avslå», uansett hva serveren kalte den.
        let avslag = try #require(g.forespørsel(for: g.avslaa))
        #expect(avslag.valg == .avslaa && avslag.valg.label == "Avslå" && !avslag.valg.krevAutentisering)
        // En handling med nøkkelen «deny» kalt noe annet er fortsatt Avslå.
        #expect(Svarvalg(key: "deny", label: "Utfør alt").label == "Avslå")
    }

    @Test func etikettMedRetningstegnRensesOveralt() throws {
        let farlig = "Se\u{202E}nd\u{2066}x\u{2069}\u{200F}\u{200B}\u{FEFF}"
        let g = skjermMed(kort([.init(key: "send", label: farlig), .init(key: "deny", label: "Avslå")]))
        let h = try #require(g.godkjenn)
        let f = try #require(g.forespørsel(for: h))
        let alle = [h.label, h.etikett, f.valg.label, f.valg.etikett, f.begrunnelse, f.konsekvens, Svar.usikkerVisning(for: f).melding]
        let forbudt = Set("\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2066}\u{2067}\u{2068}\u{2069}\u{200E}\u{200F}\u{200B}\u{2060}\u{FEFF}".unicodeScalars)
        for t in alle { #expect(!t.unicodeScalars.contains { forbudt.contains($0) }, "tegn i \(t.debugDescription)") }
        #expect(h.etikett == "Sendx")
        #expect(h.label == "Godkjenn «Sendx»")
    }

    @Test func ledendeEmojiOgSymbolerFjernes() {
        #expect(Svarvalg(key: "send", label: "✉️ Send").etikett == "Send")
        #expect(Svarvalg(key: "draft", label: "💾 Lagre utkast").etikett == "Lagre utkast")
        #expect(Svarvalg(key: "x", label: "✅  ✨ Ja   takk ").etikett == "Ja takk")
        #expect(Svarvalg(key: "x", label: "Send «nå»").etikett == "Send nå", "anførselstegn kan ikke lukke etikettens egne")
        #expect(Svarvalg(key: "x", label: "Send 📧").etikett == "Send 📧", "bare LEDENDE emoji fjernes")
    }

    @Test func tomEllerBareEmojiEtikettFallerTilNøkkelen() {
        #expect(Svarvalg(key: "send", label: "").etikett == "send")
        #expect(Svarvalg(key: "send", label: "   ").etikett == "send")
        #expect(Svarvalg(key: "send", label: "✉️").etikett == "send")
        #expect(Svarvalg(key: "send", label: "\u{202E}\u{200B}").label == "Godkjenn «send»")
        #expect(Svarvalg(key: "\u{202E}", label: "").etikett == "valg", "også en tom nøkkel gir noe å vise")
    }

    @Test func langEtikettKuttesMedTrepunktum() {
        let v = Svarvalg(key: "x", label: String(repeating: "a", count: 80))
        #expect(v.etikett.count == 24 && v.etikett.hasSuffix("…"))
        #expect(Svarvalg(key: "x", label: String(repeating: "a", count: 24)).etikett.count == 24)
        #expect(!Svarvalg(key: "x", label: String(repeating: "a", count: 24)).etikett.contains("…"))
        #expect(Svarvalg(key: String(repeating: "k", count: 60), label: "").etikett.count == 24)
    }

    @Test func standardkortetsKonsekvensBærerKortetsMål() {
        let f = forespørsel(godkjenn, tekst: "Rull ut eksempeltjenesten\n\nDetaljer")
        #expect(f.konsekvens == "«Rull ut eksempeltjenesten» utføres så snart du godkjenner. Krever Face ID eller enhetskode.")
        let lang = forespørsel(godkjenn, tekst: String(repeating: "x", count: 200))
        #expect(lang.konsekvens.contains("…"))
        #expect(forespørsel(.avslaa).konsekvens == "Forespørselen forkastes. Ingenting utføres.")
    }

    // MARK: - K1 og K2

    @Test func kortMedBareDenyHarIngenGodkjennVei() {
        let g = skjermMed(kort([.init(key: "deny", label: "Avslå")]))
        #expect(g.godkjenn == nil)
        #expect(g.forespørsel(for: NaaSkjerm.Handling(kortId: g.id, valg: .godkjenn, key: "approve")) == nil)
        #expect(skjermMed(kort(nil)).godkjenn?.key == "approve")
        #expect(skjermMed(kort([])).godkjenn?.key == "approve")
    }

    @Test func kvitteringenLåserIkkeAndreKort() {
        var s = ibekreftelse(.avslaa)
        guard case .send(let f) = s.bekreft() else { return }
        #expect(s.knapper(for: "demo-alarm") == .sender(f.forespørsel))
        #expect(s.knapper(for: "annet-kort-1") == .av, "andre kort er av mens noe sendes")
        _ = s.resultat(id: f.id, .utfall(.avgjort))
        guard case .ferdig = s.tilstand else { Issue.record("ventet .ferdig"); return }
        #expect(s.knapper(for: "annet-kort-1") == .aktive, "kvitteringen låser ingenting")
        #expect(s.knapper(for: "demo-alarm") == .aktive)
        s.velg(forespørsel(godkjenn, id: "annet-kort-1"))
        if case .bekrefter = s.tilstand {} else { Issue.record("skulle kunne velge et annet kort under kvitteringen") }
    }

    @Test func usikkerOgAutentiseringSlårAvAndreKort() {
        var s = ibekreftelse(godkjenn)
        guard case .autentiser(let fo) = s.bekreft() else { return }
        #expect(s.knapper(for: "annet-kort-1") == .av)
        _ = s.autentisert(id: fo.id, utfall: .ok)
        _ = s.resultat(id: fo.id, .feil(.nettverk("x")))
        #expect(s.knapper(for: "annet-kort-1") == .av && s.knapper(for: "demo-alarm") == .usikker(fo.forespørsel))
        s.lukk()
        #expect(s.knapper(for: "annet-kort-1") == .aktive)
    }
}
