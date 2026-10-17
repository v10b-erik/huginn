import SwiftUI
import AppCore

/// Tilstanden bak «Tråder»: siste vellykkede skjerm, siste feil, og om vi henter akkurat nå. En feil ved
/// oppdatering beholder forrige liste (feilen vises over den) i stedet for å tømme den. Aldri en stille reserve.
@MainActor @Observable
final class TraaderModell {
    private(set) var skjerm: TraadSkjerm?
    private(set) var feil: NaaFeil?
    private(set) var henter = false
    private let kilde: any TraadKilde

    init(kilde: any TraadKilde) { self.kilde = kilde }

    func last() async {
        guard !henter else { return }
        henter = true
        defer { henter = false }
        do {
            let ny = try await kilde.hent()
            skjerm = ny
            feil = nil
        } catch {
            // En avbrutt henting (pull-to-refresh som slippes, visning som forsvinner) er ikke en feil.
            if Task.isCancelled || (error as? URLError)?.code == .cancelled || error is CancellationError { return }
            feil = NaaFeil.fra(error)
        }
    }
}
