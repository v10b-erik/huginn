import SwiftUI
import AppCore

/// Tilstanden bak «Nå»: siste vellykkede skjerm, siste feil, og om vi henter akkurat nå. En feil ved
/// oppdatering beholder forrige skjerm (feilen vises over den) i stedet for å tømme den.
@MainActor @Observable
final class NaaModell {
    private(set) var skjerm: NaaSkjerm?
    private(set) var feil: NaaFeil?
    private(set) var henter = false
    /// Når siste henting lyktes (til tilkoblingsarket: «siste kontakt»).
    private(set) var sisteKontakt: Date?
    private let kilde: any NaaKilde
    /// Skriveveien (Godkjenn/Avslå). `nil` = ingen skrivevei: brikken har da ingen knapper («Venter på svar» står i stedet),
    /// ikke deaktiverte. Skjer ikke i appen (RotView gir alltid autentisering); finnes for tester og forhåndsvisninger.
    private(set) var svar: SvarTjeneste?

    init(kilde: any NaaKilde, send: SvarTjeneste.Send? = nil, autentisering: (any Autentisering)? = nil) {
        self.kilde = kilde
        if let send, let autentisering {
            svar = SvarTjeneste(autentisering: autentisering, send: send, oppfrisk: { [weak self] in
                await self?.lastEtterSvar()
            })
        }
    }

    /// Skjermen slik den tegnes: uten kort som allerede er avgjort her.
    var synligSkjerm: NaaSkjerm? {
        guard var s = skjerm else { return nil }
        // Kort serveren har avgjort vises ikke igjen, selv om oppfriskningen etterpå feilet (tjenesten fører listen).
        let skjult = svar?.avgjorte ?? []
        s.godkjenninger.removeAll { skjult.contains($0.id) }
        return s
    }

    // MARK: - Godkjenn/Avslå

    /// Brikkens knapp: åpner bekreftelsen (sender ingenting).
    func velg(_ handling: NaaSkjerm.Handling) {
        guard let svar, let g = skjerm?.godkjenninger.first(where: { $0.id == handling.kortId }),
              let f = g.forespørsel(for: handling) else { return }
        svar.velg(f)
    }

    /// Knappen i bekreftelsen. Flyten eies av en egen oppgave som holder tjenesten i live, så den ikke avbrytes av
    /// at visningen forsvinner midt i en forsendelse (da ville vi ikke vite hva som skjedde).
    func bekreftSvar() {
        guard let svar else { return }
        Task { await svar.bekreft() }
    }

    func lukkSvar() { svar?.lukk() }

    /// «Oppdater» på en usikker eller mislykket forsendelse: kvitter og hent på nytt. Sender ingenting.
    func oppdaterEtterSvar() async {
        svar?.lukk()
        await lastEtterSvar()
    }

    /// Henting etter et svar skal ikke hoppes over fordi en eldre henting pågår (den kan være sendt før svaret):
    /// vent på den, og hent så på nytt.
    private func lastEtterSvar() async {
        for _ in 0..<200 where henter { try? await Task.sleep(for: .milliseconds(25)) }
        await last()
    }

    func last() async {
        guard !henter else { return }
        henter = true
        defer { henter = false }
        do {
            let ny = try await kilde.hent()
            skjerm = ny
            sisteKontakt = Date()
            feil = nil
        } catch {
            // En avbrutt henting (pull-to-refresh som slippes, visning som forsvinner) er ikke en feil.
            if Task.isCancelled || (error as? URLError)?.code == .cancelled || error is CancellationError { return }
            feil = NaaFeil.fra(error)
        }
    }
}
