import SwiftUI
import AppCore

/// Hovednavigasjonen. Bare «Nå» er i bruk; de andre er deaktivert til skjermene finnes. Valgt fane er
/// TONET, aldri fylt (identitet regel 2), så den ikke leses som en handling.
struct Tabbar: View {
    struct Fane: Identifiable {
        var id: String
        var tittel: String
        var aktiv: Bool
        var valgt: Bool
        var identifier: String
    }

    static let faner = [
        Fane(id: "naa", tittel: "Nå", aktiv: true, valgt: true, identifier: "tabNaa"),
        Fane(id: "traader", tittel: "Tråder", aktiv: false, valgt: false, identifier: "tabTraader"),
        Fane(id: "ko", tittel: "Kø", aktiv: false, valgt: false, identifier: "tabKo"),
        Fane(id: "samtale", tittel: "Samtale", aktiv: false, valgt: false, identifier: "tabSamtale"),
    ]

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        HStack(spacing: Theme.Avstand.s2) {
            ForEach(Self.faner) { fane in
                Button {} label: {
                    Text(fane.tittel)
                        .skrift(.tab)
                        .foregroundStyle(fane.valgt ? Color(p.aksent) : Color(p.tekst))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: Theme.Maal.tab)
                        .glassFlate(radius: Theme.Radius.knapp, variant: fane.valgt ? .valgt : .glass)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!fane.aktiv)
                .opacity(fane.aktiv ? 1 : 0.45)
                .accessibilityIdentifier(fane.identifier)
                .accessibilityLabel(fane.tittel)
                .accessibilityHint(fane.aktiv ? "" : "Kommer")
                .accessibilityAddTraits(fane.valgt ? [.isSelected] : [])
            }
        }
    }
}
