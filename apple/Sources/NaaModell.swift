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

    init(kilde: any NaaKilde) {
        self.kilde = kilde
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
