import SwiftUI
import AppCore

/// Liste i glass (avvik, ventende, tråder): sperret overskrift, så rader med lampe, tittel og tilstand.
struct Listebrikke: View {
    var tittel: String
    var hoyre: String? = nil
    var rader: [NaaSkjerm.Rad]
    /// Vises når listen er tom (tråder), ellers utelates hele brikken av kalleren.
    var tomTekst: String? = nil
    var idPrefiks: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        Brikke(padding: EdgeInsets(top: Theme.Avstand.s4, leading: Theme.Avstand.s5, bottom: Theme.Avstand.s3, trailing: Theme.Avstand.s5)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(tittel).skrift(.etikett).foregroundStyle(Color(p.dempet))
                    Spacer()
                    if let hoyre { Text(hoyre).skrift(.tid).foregroundStyle(Color(p.dempet)) }
                }
                .padding(.bottom, Theme.Avstand.s3)
                .accessibilityAddTraits(.isHeader)
                // Strek under overskriften, som i prototypen (første rad har alltid en strek over seg).
                Rectangle().fill(Color(p.kant)).frame(height: 1)

                if rader.isEmpty, let tomTekst {
                    Text(tomTekst).skrift(.tekst).foregroundStyle(Color(p.dempet))
                        .padding(.vertical, Theme.Avstand.s3)
                }
                ForEach(Array(rader.enumerated()), id: \.element.id) { i, rad in
                    if i > 0 { Rectangle().fill(Color(p.kant)).frame(height: 1) }
                    RadView(rad: rad)
                        .accessibilityIdentifier("\(idPrefiks)Rad\(i)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(idPrefiks)
    }
}

private struct RadView: View {
    var rad: NaaSkjerm.Rad
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        HStack(alignment: .center, spacing: Theme.Avstand.s3) {
            Circle().fill(lampefarge(rad.tone, p)).frame(width: Theme.Maal.led, height: Theme.Maal.led)
                .frame(width: 14, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(rad.tittel).skrift(.tekst)
                    .foregroundStyle(Color(p.tekst))
                    .lineLimit(2)
                if let u = rad.undertekst {
                    Text(u).skrift(.undertekst).foregroundStyle(Color(p.dempet)).lineLimit(2)
                }
            }
            Spacer(minLength: Theme.Avstand.s2)
            if let ord = rad.ord {
                Text(ord).skrift(.status).foregroundStyle(tekstfarge(rad.tone, p))
            } else if let tid = rad.tid {
                Text(tid).skrift(.tid).monospacedDigit().foregroundStyle(Color(p.dempet))
            }
        }
        .padding(.vertical, Theme.Avstand.s3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [rad.tittel, rad.undertekst, rad.ord?.lowercased(), rad.tid].compactMap { $0 }.joined(separator: ", ")
        )
    }
}
