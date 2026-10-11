import SwiftUI
import AppCore

/// Én tallkolonne: etikett, stort tall, evt. strek (bare der den betyr noe) og en linje tekst.
struct KolonneTall: View {
    var kolonne: NaaSkjerm.Kolonne
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        VStack(alignment: .leading, spacing: Theme.Avstand.s2) {
            Text(kolonne.tittel).skrift(.etikett).foregroundStyle(Color(p.dempet))
            Text("\(kolonne.verdi)")
                .skrift(.tall)
                .monospacedDigit()
                .foregroundStyle(kolonne.tone == .feil ? Color(p.feil) : Color(p.tekst))
            Text(kolonne.tekst).skrift(.undertekst).foregroundStyle(Color(p.dempet)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kolonne.tittel), \(kolonne.verdi), \(kolonne.tekst)")
    }
}
