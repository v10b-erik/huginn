import SwiftUI
import AppCore

/// Innfelt bånd («Fra», «Klasse»): sperret etikett + verdi, evt. et tilstandsord til høyre.
struct Band: View {
    var etikett: String
    var verdi: String
    var ord: String? = nil
    var ordTone: NaaSkjerm.Tone = .ok
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        HStack(spacing: Theme.Avstand.s3) {
            Text(etikett).skrift(.etikettAksent).foregroundStyle(Color(p.aksent))
            Text(verdi).skrift(.tekst).foregroundStyle(Color(p.tekst)).lineLimit(2)
            Spacer(minLength: Theme.Avstand.s2)
            if let ord {
                Text(ord).skrift(.etikettAksent).foregroundStyle(tekstfarge(ordTone, p))
            }
        }
        .padding(.horizontal, Theme.Avstand.s4)
        .padding(.vertical, Theme.Avstand.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.band, style: .continuous).fill(Color(p.band))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.band, style: .continuous).strokeBorder(Color(p.kant), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(etikett): \(verdi)" + (ord.map { ", \($0.lowercased())" } ?? ""))
    }
}
