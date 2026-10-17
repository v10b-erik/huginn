import SwiftUI
import AppCore

/// Hovednavigasjonen. Den viser BARE fanene som finnes (`Hovedfane`): en fane for en skjerm som ikke er bygd ville
/// late som, og en trykkbar plassholder er det identiteten ikke vil ha. Kø og Samtale kommer når skjermene gjør det.
/// Valgt fane er TONET, aldri fylt (identitet regel 2), så den ikke leses som en handling.
struct Tabbar: View {
    var valgt: Hovedfane
    var onVelg: (Hovedfane) -> Void

    /// Fanenes tekst er alltid en TEKSTrolle fra paletten (identitet regel 10, ≥ 4,5:1): `aksent` når valgt,
    /// ellers `dempet`.
    static func tekstfarge(valgt: Bool, palett p: Theme.Palette) -> Theme.RGBA {
        valgt ? p.aksent : p.dempet
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        HStack(spacing: Theme.Avstand.s2) {
            ForEach(Hovedfane.allCases) { fane in
                let erValgt = fane == valgt
                Button { onVelg(fane) } label: {
                    Text(fane.tittel)
                        .skrift(.tab)
                        .foregroundStyle(Color(Self.tekstfarge(valgt: erValgt, palett: p)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: Theme.Maal.tab)
                        .glassFlate(radius: Theme.Radius.knapp, variant: erValgt ? .valgt : .glass)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(fane.identifier)
                .accessibilityLabel(fane.tittel)
                .accessibilityAddTraits(erValgt ? [.isSelected] : [])
            }
        }
    }
}
