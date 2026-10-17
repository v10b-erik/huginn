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
        let indre = Theme.Radius.knapp - Self.innrykk  // konsentrisk med panelet, og lik `chip` (14)
        // ÉN glassflate med fanene inni (ikke to knapper side om side, som leses som et handlingspar). Valgt fane er
        // tonet og aldri fylt (regel 2), uten egen skygge; ikke-valgt har ingen flate i det hele tatt.
        HStack(spacing: Theme.Avstand.s1) {
            ForEach(Hovedfane.allCases) { fane in
                let erValgt = fane == valgt
                Button { onVelg(fane) } label: {
                    Text(fane.tittel)
                        .skrift(.tab)
                        .foregroundStyle(Color(Self.tekstfarge(valgt: erValgt, palett: p)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: Theme.Maal.tab - 2 * Self.innrykk)
                        .background {
                            if erValgt {
                                let form = RoundedRectangle(cornerRadius: indre, style: .continuous)
                                form.fill(LinearGradient(colors: [Color(p.aksentTone), Color(p.krever2)], startPoint: .top, endPoint: .bottom))
                                    .overlay(form.strokeBorder(Color(p.aksentKant), lineWidth: 1))
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(fane.identifier)
                .accessibilityLabel(fane.tittel)
                .accessibilityAddTraits(erValgt ? [.isSelected] : [])
            }
        }
        .padding(Self.innrykk)
        .glassFlate(radius: Theme.Radius.knapp)
    }

    private static let innrykk: Double = 4
}
