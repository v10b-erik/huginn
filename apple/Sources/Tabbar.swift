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

    /// Fanenes tekst er alltid en TEKSTrolle fra paletten (identitet regel 10, ≥ 4,5:1): `aksent` når valgt,
    /// ellers `dempet`. En fane som ikke finnes ennå kan ikke trykkes, men blekner ikke: ingen egen opasitet.
    static func tekstfarge(valgt: Bool, palett p: Theme.Palette) -> Theme.RGBA {
        valgt ? p.aksent : p.dempet
    }
    static let opasitet = 1.0

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        HStack(spacing: Theme.Avstand.s2) {
            ForEach(Self.faner) { fane in
                Button {} label: {
                    Text(fane.tittel)
                        .skrift(.tab)
                        .foregroundStyle(Color(Self.tekstfarge(valgt: fane.valgt, palett: p)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: Theme.Maal.tab)
                        .glassFlate(radius: Theme.Radius.knapp, variant: fane.valgt ? .valgt : .glass)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Ikke `.disabled`: SwiftUI blekner da etiketten under kontrastkravet. Inaktive faner har en
                // handling som ikke gjør noe, og VoiceOver får beskjed.
                .allowsHitTesting(fane.aktiv)
                .opacity(Self.opasitet)
                .accessibilityIdentifier(fane.identifier)
                .accessibilityLabel(fane.tittel)
                .accessibilityHint(fane.aktiv ? "" : "Kommer")
                .accessibilityAddTraits(fane.valgt ? [.isSelected] : [])
            }
        }
    }
}
