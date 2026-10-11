import SwiftUI
import AppCore

/// Roten: velger mellom «Koble til» og «Nå» etter `Innlogging`-tilstanden, og eier arket fra statusbrikken.
struct RotView: View {
    @State var modell: InnloggingModell
    @State private var visArk = Forhandsvisning.visArkVedStart
    @State private var kontakt: Kontakt = .ukjent
    private let forhandsvisning: Forhandsvisning

    /// Synsløkka (bare DEBUG): forhåndsutfyll feltene og send, med falske verdier, slik at skjermbilder av
    /// feil og «Kobler til» går gjennom den ekte veien. I release er dette alltid tomt.
    struct Forhandsvisning {
        /// `nil`: den lagrede adressen (ved «Koble til på nytt»), ellers standardadressen.
        var adresse: String?
        var token = ""
        var send = false
        var fokusToken = false

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
                adresse: verdi("--kobling-adresse"),
                token: verdi("--kobling-token") ?? "",
                send: argumenter.contains("--kobling-send"),
                fokusToken: argumenter.contains("--fokus-token")
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
            case .ikkeKoblet, .kobler:
                // ÉN gren for begge: to grener ville gjenskapt viewet ved hvert forsøk og nullstilt det du har skrevet.
                kobling
            case .koblet(let t):
                naa(valg: t.kildeValg, nyttToken: { modell.visKobling() })
            case .demo(let rolig, let ekte):
                // Demo avgjør lokalt (kortet forsvinner, ingen nettverk); live sender til trådflata etter bekreftelse
                // og autentisering.
                naa(valg: .demo(rolig: rolig, ekte: ekte), nyttToken: nil)
            }
        }
        .sheet(isPresented: $visArk) {
            TilkoblingArk(
                visning: ArkVisning.fra(
                    tilstand: modell.tilstand, kontakt: kontakt, harLagret: modell.innlogging.lagret != nil,
                    handlingsFeil: modell.innlogging.handlingsFeil
                ),
                // Lukkes bare når frakoblingen faktisk gikk gjennom. Feiler den, blir arket stående og viser feilen.
                onKobleFra: { if modell.kobleFra() { visArk = false } },
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

    private var kobling: some View {
        var feil: TilkoblingsFeil?
        var kobler = false
        switch modell.tilstand {
        case .ikkeKoblet(let f): feil = f
        case .kobler: kobler = true
        default: break
        }
        return KoblingView(
            feil: feil, kobler: kobler, kanAvbryte: modell.innlogging.kanAvbryte,
            // «Koble til på nytt» etter 401 fyller inn den LAGREDE adressen, ikke standardadressen.
            forhandsadresse: forhandsvisning.adresse ?? modell.innlogging.lagret?.adresse ?? Tilkobling.standardAdresse,
            forhandstoken: forhandsvisning.token, sendVedStart: forhandsvisning.send, fokusVedStart: forhandsvisning.fokusToken,
            onKoble: { adresse, token in modell.kobleIBakgrunn(adresse: adresse, token: token) },
            onDemo: { modell.prøvDemo() },
            onAvbryt: { modell.avbryt() },
            onAvbrytKobling: { modell.avbrytKobling() }
        )
    }

    private func naa(valg: KildeValg, nyttToken: (() -> Void)?) -> some View {
        #if DEBUG
        // Synsløkka: `--demo-vert=<host>` får en demo til å se ut som en live-kilde i foten.
        let demoVert = KildeValg.demoVert(argumenter: ProcessInfo.processInfo.arguments, tillatLive: true)
        #else
        let demoVert: String? = nil
        #endif
        let fot = valg.fot(demoVert: demoVert)
        let argumenter = ProcessInfo.processInfo.arguments
        #if DEBUG
        let demo = KildeValg.demoAvgjort(argumenter: argumenter, tillatLive: true)
        #else
        let demo = KildeValg.demoAvgjort(argumenter: argumenter, tillatLive: false)
        #endif
        return NaaView(
            tilgang: valg.lagTilgang(demo: demo), autentisering: velgAutentisering(argumenter: argumenter, valg: valg), valg: valg,
            kildeNavn: fot.full, smaltKildeNavn: fot.smal,
            onTilkobling: { visArk = true }, onKobleTilPaaNytt: nyttToken,
            onKontakt: { kontakt = $0 }
        )
        // Ny tilkobling = fersk modell og kilde (aldri det forrige tokenets data).
        .id(modell.generasjon)
    }
}
