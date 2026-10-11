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
        #expect(Svarvalg.godkjenn(actions: [d, a]).key == "approve")
        let u = NaaKort.Handling(key: "deploy", label: "Rull ut")
        #expect(Svarvalg.godkjenn(actions: [u, d]) == Svarvalg(key: "deploy", label: "Rull ut"), "serveren avviser approve når kortet har andre handlinger")
        #expect(Svarvalg.godkjenn(actions: [d]).key == "approve", "deny blir aldri et Godkjenn")
        #expect(Svarvalg.godkjenn(actions: [d]).krevAutentisering)
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
        #expect(Svar.usikkerVisning == SvarVisning(ord: "USIKKERT", melding: "Usikkert om svaret ble registrert. Kortet er borte hvis det gikk gjennom."))
    }

    @Test func begrunnelsenBærerFørsteLinjeOgAldriMer() {
        let f = forespørsel(godkjenn, tekst: "\n  Rull ut eksempeltjenesten  \nHemmelig andre linje")
        #expect(f.forsteLinje == "Rull ut eksempeltjenesten")
        #expect(f.begrunnelse == "Godkjenn: Rull ut eksempeltjenesten")
        let lang = forespørsel(godkjenn, tekst: String(repeating: "x", count: 300))
        #expect(lang.begrunnelse.count <= "Godkjenn: ".count + 80)
        #expect(lang.begrunnelse.hasSuffix("…"))
        #expect(forespørsel(godkjenn, tekst: "   \n ").forsteLinje == "Godkjenning")
    }
}
