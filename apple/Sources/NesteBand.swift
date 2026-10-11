import SwiftUI
import AppCore

/// «NESTE»/«SÅ»: ett smalt glassbånd per kommende hendelse. Etiketten er dempet, ikke aksent (regel 1).
struct NesteBand: View {
    var neste: NaaSkjerm.Neste
    /// Fast bredde på etiketten, så «Trening» og «Standup» starter på samme x.
    @ScaledMetric(relativeTo: .caption) private var etikettBredde = 52
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        HStack(spacing: Theme.Avstand.s3) {
            Text(neste.etikett).skrift(.etikett).foregroundStyle(Color(p.dempet))
                .frame(width: etikettBredde, alignment: .leading)
            Text(neste.tittel).skrift(.tekst).foregroundStyle(Color(p.tekst)).lineLimit(1)
            Spacer(minLength: Theme.Avstand.s2)
            Text(neste.tid).skrift(.tid).foregroundStyle(Color(p.dempet)).lineLimit(1)
        }
        .padding(.horizontal, Theme.Avstand.s4)
        .padding(.vertical, Theme.Avstand.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassFlate(radius: Theme.Radius.chip)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(neste.etikett.lowercased()): \(neste.tittel), \(neste.tid)")
    }
}
