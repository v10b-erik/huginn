import SwiftUI
import AppCore

/// Holder `Innlogging` for viewene og gjør det eneste tilstandsmaskinen ikke gjør: kaller nettverket for å
/// bekrefte. Lagring skjer inne i `Innlogging.kobletOk`, altså bare etter en vellykket bekreftelse.
@MainActor @Observable
final class InnloggingModell {
    typealias Bekreft = @Sendable (Tilkobling) async throws -> Void

    private(set) var innlogging: Innlogging
    /// Øker ved hver endring av hva som vises, så «Nå» får en fersk modell (og kilde) når tilkoblingen byttes.
    private(set) var generasjon = 0
    private let bekreft: Bekreft
    /// Hvilket forsøk som gjelder. Et forsøk som er avbrutt eller forbikjørt får aldri røre tilstanden eller
    /// lageret, selv om bekreftelsen likevel kommer tilbake (nettverket respekterer ikke alltid avbrudd).
    private var forsøk = 0
    private var oppgave: Task<Void, Never>?
    /// Kalles når en Kobling nettopp gikk gjennom (ikke ved start med lagret tilkobling). Brukes til å be om varsler.
    var onKoblet: (() -> Void)?

    init(lager: any TilkoblingLager, tillatHttpLoopback: Bool, bekreft: @escaping Bekreft = { try await bekreftTilkobling($0) }) {
        innlogging = Innlogging(lager: lager, tillatHttpLoopback: tillatHttpLoopback)
        self.bekreft = bekreft
    }

    var tilstand: Innlogging.Tilstand { innlogging.tilstand }

    func start(argumenter: [String], miljo: [String: String], tillatLive: Bool) {
        endre { $0.start(argumenter: argumenter, miljo: miljo, tillatLive: tillatLive) }
    }

    /// Fra knappen: eier oppgaven, så «Avbryt» kan stoppe den.
    func kobleIBakgrunn(adresse: String, token: String) {
        oppgave = Task { [weak self] in await self?.koble(adresse: adresse, token: token) }
    }

    /// Validerer, bekrefter mot trådflata, og lagrer først deretter. Tilstanden står på `.kobler` underveis.
    func koble(adresse: String, token: String) async {
        var t: Tilkobling?
        endre { t = $0.koble(adresse: adresse, token: token) }
        guard let t else { return }
        forsøk += 1
        let mitt = forsøk
        do {
            try await bekreft(t)
            guard mitt == forsøk else { return }
            endre { $0.kobletOk(t) }
            if case .koblet = tilstand { onKoblet?() }
        } catch let f as TilkoblingsFeil {
            guard mitt == forsøk else { return }
            endre { $0.kobletFeilet(f) }
        } catch {
            // Avbrutt (CancellationError): tilbake til skjemaet uten feilrad. Avbrudd er ikke en feil.
            guard mitt == forsøk else { return }
            endre { $0.avbrytKobler() }
        }
    }

    /// «Avbryt» under «Kobler til»: ingen lagring, ingen feil, og et sent svar fra forsøket teller ikke.
    func avbrytKobling() {
        forsøk += 1
        oppgave?.cancel()
        oppgave = nil
        endre { $0.avbrytKobler() }
    }

    /// Gir `true` når du faktisk er koblet fra. Feiler slettingen, står du fortsatt koblet til, og
    /// `innlogging.handlingsFeil` sier hvorfor (arket skal da bli stående åpent og vise den).
    @discardableResult
    func kobleFra() -> Bool {
        endre { $0.kobleFra() }
        if case .koblet = tilstand { return false }
        return true
    }

    func prøvDemo(rolig: Bool = false) { endre { $0.prøvDemo(rolig: rolig) } }
    func visKobling() { endre { $0.visKobling() } }
    func avbryt() { endre { $0.avbryt() } }
    func brukLagret() { endre { $0.brukLagret() } }

    private func endre(_ f: (inout Innlogging) -> Void) {
        let før = innlogging.tilstand
        f(&innlogging)
        if innlogging.tilstand != før { generasjon += 1 }
    }
}
