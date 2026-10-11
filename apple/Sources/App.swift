import SwiftUI
import AppCore
import os

@main
struct HuginnApp: App {
    @State private var modell: InnloggingModell
    private let forhandsvisning: RotView.Forhandsvisning

    init() {
        let mangler = Fonter.registrer()
        if !mangler.isEmpty {
            // Font.custom faller stille tilbake til systemfonten; her sier vi fra.
            Logger(subsystem: "no.huginn", category: "fonter").error("fonter mangler: \(mangler.joined(separator: ", "), privacy: .public)")
        }
        #if DEBUG
        let debug = true
        #else
        let debug = false
        #endif
        let argumenter = ProcessInfo.processInfo.arguments
        // `http` mot loopback og DEBUG-miljøet (HUGINN_URL/HUGINN_TOKEN) er bare for DEBUG-bygg.
        let m = InnloggingModell(lager: KeychainLager(tillatHttpLoopback: debug), tillatHttpLoopback: debug)
        m.start(argumenter: argumenter, miljo: ProcessInfo.processInfo.environment, tillatLive: debug)
        // Bare tilstandsnavnet, aldri tokenet (Tilkobling og KildeValg er redigert).
        let navn: String
        switch m.tilstand {
        case .koblet(let t): navn = t.kildeValg.navn
        case .demo(let rolig): navn = KildeValg.demo(rolig: rolig).navn
        default: navn = "ikke koblet"
        }
        Logger(subsystem: "no.huginn", category: "kilde").info("kilde: \(navn, privacy: .public)")
        _modell = State(initialValue: m)
        forhandsvisning = RotView.Forhandsvisning.fra(argumenter: argumenter)
    }

    var body: some Scene {
        WindowGroup {
            RotView(modell: modell, forhandsvisning: forhandsvisning)
        }
    }
}
