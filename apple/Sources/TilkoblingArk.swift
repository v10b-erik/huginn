import SwiftUI
import AppCore

/// Lite ark fra «Plattform ok»-brikken: hvor du er koblet til (VERT, aldri tokenet), og veien ut.
struct TilkoblingArk: View {
    var tilstand: Innlogging.Tilstand
    var harLagret: Bool
    var handlingsFeil: TilkoblingsFeil?
    var onKobleFra: () -> Void
    var onDemo: () -> Void
    var onKoble: () -> Void
    var onBrukLagret: () -> Void
    var onFerdig: () -> Void

    @State private var bekreftFra = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        VStack(alignment: .leading, spacing: Theme.Avstand.s3) {
            HStack {
                Text("Tilkobling").skrift(.etikett).foregroundStyle(Color(p.dempet))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onFerdig) { Text("Ferdig").skrift(.etikettAksent).foregroundStyle(Color(p.aksent)) }
                    .frame(minWidth: Theme.Maal.beroringMin, minHeight: Theme.Maal.beroringMin)
                    .accessibilityIdentifier("tilkobling.ferdig")
            }
            switch tilstand {
            case .koblet(let t):
                Band(etikett: "Vert", verdi: t.vert)
                    .accessibilityIdentifier("tilkobling.vert")
                knapp("Bytt til demo", id: "tilkobling.demo", action: onDemo)
                knapp("Koble fra", id: "tilkobling.kobleFra") { bekreftFra = true }
            case .demo:
                Band(etikett: "Kilde", verdi: "Demo")
                    .accessibilityIdentifier("tilkobling.kilde")
                if harLagret {
                    knapp("Bruk lagret tilkobling", id: "tilkobling.brukLagret", action: onBrukLagret)
                }
                knapp("Koble til trådflata", id: "tilkobling.koble", action: onKoble)
            default:
                EmptyView()
            }
            if let handlingsFeil {
                HStack(alignment: .top, spacing: Theme.Avstand.s3) {
                    Circle().fill(Color(p.feil)).frame(width: Theme.Maal.led, height: Theme.Maal.led).padding(.top, 4)
                    VStack(alignment: .leading, spacing: Theme.Avstand.s1) {
                        Text(handlingsFeil.ord).skrift(.status).foregroundStyle(Color(p.feil))
                        Text(handlingsFeil.melding).skrift(.undertekst).foregroundStyle(Color(p.tekst))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(handlingsFeil.tilgjengeligTekst)
                .accessibilityIdentifier("tilkobling.feil")
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Avstand.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Bakgrunn())
        .confirmationDialog("Koble fra trådflata?", isPresented: $bekreftFra, titleVisibility: .visible) {
            Button("Koble fra", role: .destructive, action: onKobleFra)
                .accessibilityIdentifier("tilkobling.kobleFraBekreft")
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Tokenet slettes fra Keychain på denne enheten. Du må lime det inn igjen for å koble til.")
        }
        #if os(iOS)
        .presentationDetents([.height(330), .medium])
        .presentationDragIndicator(.visible)
        #else
        .frame(minWidth: 340, minHeight: 300)
        #endif
    }

    private func knapp(_ tekst: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(tekst).skrift(.knapp) }
            .buttonStyle(KnappStil(rolle: .sekundar))
            .accessibilityIdentifier(id)
    }
}
