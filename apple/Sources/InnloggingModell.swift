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

    init(lager: any TilkoblingLager, tillatHttpLoopback: Bool, bekreft: @escaping Bekreft = { try await bekreftTilkobling($0) }) {
        innlogging = Innlogging(lager: lager, tillatHttpLoopback: tillatHttpLoopback)
        self.bekreft = bekreft
    }

    var tilstand: Innlogging.Tilstand { innlogging.tilstand }

    func start(argumenter: [String], miljo: [String: String], tillatLive: Bool) {
        endre { $0.start(argumenter: argumenter, miljo: miljo, tillatLive: tillatLive) }
    }

    /// Validerer, bekrefter mot trådflata, og lagrer først deretter. Tilstanden står på `.kobler` underveis.
    func koble(adresse: String, token: String) async {
        var t: Tilkobling?
        endre { t = $0.koble(adresse: adresse, token: token) }
        guard let t else { return }
        do {
            try await bekreft(t)
            endre { $0.kobletOk(t) }
        } catch let f as TilkoblingsFeil {
            endre { $0.kobletFeilet(f) }
        } catch {
            // Avbrutt (CancellationError): ikke la skjermen bli stående på «Kobler til».
            endre { $0.kobletFeilet(.ikkeNaabar) }
        }
    }

    func kobleFra() { endre { $0.kobleFra() } }
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
