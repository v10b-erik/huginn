import SwiftUI
import AppCore

/// Roten: velger mellom «Koble til» og «Nå» etter `Innlogging`-tilstanden, og eier arket fra statusbrikken.
struct RotView: View {
    @State var modell: InnloggingModell
    @State private var visArk = Forhandsvisning.visArkVedStart
    private let forhandsvisning: Forhandsvisning

    /// Synsløkka (bare DEBUG): forhåndsutfyll feltene og send, med falske verdier, slik at skjermbilder av
    /// feil og «Kobler til» går gjennom den ekte veien. I release er dette alltid tomt.
    struct Forhandsvisning {
        var adresse = Tilkobling.standardAdresse
        var token = ""
        var send = false

        /// Synsløkka: åpner tilkoblingsarket ved start (`--vis-ark`). Alltid `false` i release.
        static var visArkVedStart: Bool {
            #if DEBUG
            ProcessInfo.processInfo.arguments.contains("--vis-ark")
            #else
            false
            #endif
        }

        static func fra(argumenter: [String]) -> Forhandsvisning {
            #if DEBUG
            func verdi(_ navn: String) -> String? {
                argumenter.first { $0.hasPrefix("\(navn)=") }.map { String($0.dropFirst(navn.count + 1)) }
            }
            return Forhandsvisning(
                adresse: verdi("--kobling-adresse") ?? Tilkobling.standardAdresse,
                token: verdi("--kobling-token") ?? "",
                send: argumenter.contains("--kobling-send")
            )
            #else
            return Forhandsvisning()
            #endif
        }
    }

    init(modell: InnloggingModell, forhandsvisning: Forhandsvisning = Forhandsvisning()) {
        _modell = State(initialValue: modell)
        self.forhandsvisning = forhandsvisning
    }

    var body: some View {
        Group {
            switch modell.tilstand {
            case .laster:
                Bakgrunn()
            case .ikkeKoblet(let feil):
                kobling(feil: feil, kobler: false)
            case .kobler:
                kobling(feil: nil, kobler: true)
            case .koblet(let t):
                naa(valg: t.kildeValg, onSvar: nil, nyttToken: { modell.visKobling() })
            case .demo(let rolig):
                // Demo kan trykke Godkjenn/Avslå uten effekt; live har ingen skriveveier ennå, så knappene er av.
                naa(valg: .demo(rolig: rolig), onSvar: { _ in }, nyttToken: nil)
            }
        }
        .sheet(isPresented: $visArk) {
            TilkoblingArk(
                tilstand: modell.tilstand,
                harLagret: modell.innlogging.lagret != nil,
                handlingsFeil: modell.innlogging.handlingsFeil,
                onKobleFra: { visArk = false; modell.kobleFra() },
                onDemo: { visArk = false; modell.prøvDemo() },
                onKoble: { visArk = false; modell.visKobling() },
                onBrukLagret: { visArk = false; modell.brukLagret() },
                onFerdig: { visArk = false }
            )
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 700)
        #endif
    }

    private func kobling(feil: TilkoblingsFeil?, kobler: Bool) -> some View {
        KoblingView(
            feil: feil, kobler: kobler, kanAvbryte: modell.innlogging.kanAvbryte,
            forhandsadresse: forhandsvisning.adresse, forhandstoken: forhandsvisning.token, sendVedStart: forhandsvisning.send,
            onKoble: { adresse, token in Task { await modell.koble(adresse: adresse, token: token) } },
            onDemo: { modell.prøvDemo() },
            onAvbryt: { modell.avbryt() }
        )
    }

    private func naa(valg: KildeValg, onSvar: ((NaaSkjerm.Handling) -> Void)?, nyttToken: (() -> Void)?) -> some View {
        NaaView(
            kilde: valg.lagKilde(), kildeNavn: valg.navn, onSvar: onSvar,
            onTilkobling: { visArk = true }, onKobleTilPaaNytt: nyttToken
        )
        // Ny tilkobling = fersk modell og kilde (aldri det forrige tokenets data).
        .id(modell.generasjon)
    }
}
