import SwiftUI
import AppCore

/// Lite ark fra statusbrikken: status (lampe + ORD + når), hele adressen (aldri tokenet), og veien ut.
/// «Koble fra» står for seg nederst med konsekvensen under, så den ikke ligner en ufarlig modusbytte.
struct TilkoblingArk: View {
    var visning: ArkVisning
    var onKobleFra: () -> Void
    var onDemo: () -> Void
    var onKoble: () -> Void
    var onBrukLagret: () -> Void
    var onFerdig: () -> Void

    @State private var bekreftFra = false
    @State private var hoyde: CGFloat = 360
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        VStack(alignment: .leading, spacing: Theme.Avstand.s3) {
            HStack {
                Text("Tilkobling").skrift(.etikett).foregroundStyle(Color(p.dempet))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                // Dempet og stille: blå er forbeholdt det som krever deg eller pågår (regel 1).
                Button(action: onFerdig) { Text("Ferdig").skrift(.etikettAksent).foregroundStyle(Color(p.dempet)) }
                    .frame(minWidth: Theme.Maal.beroringMin, minHeight: Theme.Maal.beroringMin)
                    .accessibilityIdentifier("tilkobling.ferdig")
            }
            status(p)
            if let adresse = visning.adresse {
                Band(etikett: "Adresse", verdi: adresse, etikettDempet: true, verdiMono: true)
                    .accessibilityIdentifier("tilkobling.adresse")
            }
            if visning.kanBrukLagret { knapp("Bruk lagret tilkobling", id: "tilkobling.brukLagret", action: onBrukLagret) }
            if visning.kanKoble { knapp("Koble til trådflata", id: "tilkobling.koble", action: onKoble) }
            if visning.kanByttTilDemo { knapp("Bytt til demo", id: "tilkobling.demo", action: onDemo) }
            if let feil = visning.feil {
                HStack(alignment: .top, spacing: Theme.Avstand.s3) {
                    Circle().fill(Color(p.feil)).frame(width: Theme.Maal.led, height: Theme.Maal.led).padding(.top, 5)
                    VStack(alignment: .leading, spacing: Theme.Avstand.s1) {
                        Text(feil.ord).skrift(.status).foregroundStyle(Color(p.feil))
                        Text(feil.melding).skrift(.tekst).foregroundStyle(Color(p.dempet))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(feil.tilgjengeligTekst)
                .accessibilityIdentifier("tilkobling.feil")
            }
            if visning.kanKobleFra {
                // Skilt ut med avstand og en strek, og med konsekvensen i klartekst (ikke med farge).
                Rectangle().fill(Color(p.kant)).frame(height: 1).padding(.top, Theme.Avstand.s4)
                knapp("Koble fra", id: "tilkobling.kobleFra") { bekreftFra = true }
                Text(ArkVisning.kobleFraKonsekvens).skrift(.tekst).foregroundStyle(Color(p.dempet))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Avstand.s1)
                    .accessibilityIdentifier("tilkobling.konsekvens")
            }
        }
        .padding(Theme.Avstand.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { hoyde = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Bakgrunn())
        .confirmationDialog(ArkVisning.kobleFraTittel, isPresented: $bekreftFra, titleVisibility: .visible) {
            Button(ArkVisning.kobleFraBekreftelse, role: .destructive, action: onKobleFra)
                .accessibilityIdentifier("tilkobling.kobleFraBekreft")
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text(ArkVisning.kobleFraKonsekvens)
        }
        #if os(iOS)
        // Arket er akkurat så høyt som innholdet (pluss dra-indikatoren), ikke en fast høyde med dødt rom.
        .presentationDetents([.height(hoyde + 24)])
        .presentationDragIndicator(.visible)
        #else
        .frame(minWidth: 340, minHeight: 300)
        #endif
    }

    /// Lampe + ORD + når. Aldri farge alene.
    private func status(_ p: Theme.Palette) -> some View {
        HStack(spacing: Theme.Avstand.s3) {
            switch visning.lampe {
            case .ok: Circle().fill(Color(p.ok)).frame(width: Theme.Maal.led, height: Theme.Maal.led)
            case .avvik: Circle().fill(Color(p.feil)).frame(width: Theme.Maal.led, height: Theme.Maal.led)
            case .ingen: EmptyView()
            }
            Text(visning.ord).skrift(.status)
                .foregroundStyle(visning.lampe == .ok ? Color(p.ok) : visning.lampe == .avvik ? Color(p.feil) : Color(p.dempet))
            if let d = visning.detalj {
                Text("· \(d)").skrift(.tid).foregroundStyle(Color(p.dempet)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Avstand.s1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([visning.ord.lowercased(), visning.detalj].compactMap { $0 }.joined(separator: ", "))
        .accessibilityIdentifier("tilkobling.status")
    }

    private func knapp(_ tekst: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(tekst).skrift(.knapp) }
            .buttonStyle(KnappStil(rolle: .sekundar))
            .accessibilityIdentifier(id)
    }
}
