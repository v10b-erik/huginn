import SwiftUI
import AppCore
import os

@main
struct HuginnApp: App {
    private let valg: KildeValg

    init() {
        let mangler = Fonter.registrer()
        if !mangler.isEmpty {
            // Font.custom faller stille tilbake til systemfonten; her sier vi fra.
            Logger(subsystem: "no.huginn", category: "fonter").error("fonter mangler: \(mangler.joined(separator: ", "), privacy: .public)")
        }
        #if DEBUG
        let tillatLive = true
        #else
        let tillatLive = false
        #endif
        let valgt = KildeValg.velg(
            argumenter: ProcessInfo.processInfo.arguments,
            miljo: ProcessInfo.processInfo.environment,
            tillatLive: tillatLive
        )
        // Navnet, aldri tokenet (KildeValg.description er redigert).
        let navn = valgt.navn
        Logger(subsystem: "no.huginn", category: "kilde").info("kilde: \(navn, privacy: .public)")
        valg = valgt
    }

    var body: some Scene {
        WindowGroup {
            // Demo kan trykke Godkjenn/Avslå uten effekt; live har ingen skriveveier ennå, så knappene er av.
            NaaView(kilde: valg.lagKilde(), kildeNavn: valg.navn, onSvar: valg.erDemo ? { _ in } : nil)
                #if os(macOS)
                .frame(minWidth: 400, minHeight: 700)
                #endif
        }
    }
}
