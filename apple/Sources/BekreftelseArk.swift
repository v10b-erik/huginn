import SwiftUI
import AppCore

/// Bekreftelsen før Godkjenn/Avslå. Viser HELE kortteksten (rullbar), hva som skjer, og knappene. Sender ingenting selv:
/// «Godkjenn» her starter systemets autentisering (en egen dialog), og først etter den sendes noe.
///
/// Identiteten: Godkjenn er den fylte flaten (handling), Avslå er glass, Avbryt er stille (ingen flate). Konsekvensen står
/// som ord i et bånd (regel 4), ikke som farge.
struct BekreftelseArk: View {
    var forespørsel: Svar.Forespørsel
    /// Systemets dialog er oppe: knappen er av og sier fra (tone/kant, ingen spinner).
    var autentiserer: Bool
    var onBekreft: () -> Void
    var onAvbryt: () -> Void
    @Environment(\.colorScheme) private var scheme

    private var godkjenner: Bool { !forespørsel.valg.erAvslag }

    var body: some View {
        let p = Theme.palett(for: scheme)
        VStack(alignment: .leading, spacing: Theme.Avstand.s4) {
            Text(godkjenner ? "Godkjenn" : "Avslå")
                .skrift(.etikettAksent).foregroundStyle(Color(godkjenner ? p.aksent : p.dempet))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("godkjenn.tittel")

            // Hele teksten. Kort tekst gir en kort flate; lang tekst tar all ledig høyde og ruller (knappene under er
            // alltid synlige).
            ViewThatFits(in: .vertical) {
                ramme(tekstFlate)
                ramme(ScrollView { tekstFlate })
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .accessibilityLabel("Kort: \(forespørsel.tekst)")
            .accessibilityIdentifier("godkjenn.tekst")

            Band(etikett: "Hva skjer", verdi: konsekvens, etikettDempet: true)
            .accessibilityIdentifier("godkjenn.konsekvens")

            VStack(spacing: Theme.Avstand.s2) {
                if autentiserer {
                    Text("Bekrefter …").skrift(.knapp)
                        .foregroundStyle(Color(p.aksent))
                        .frame(maxWidth: .infinity, minHeight: Theme.Maal.knapp)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.knapp, style: .continuous).fill(Color(p.aksentTone)))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.knapp, style: .continuous).strokeBorder(Color(p.aksentKant), lineWidth: 1))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Bekrefter at det er deg")
                        .accessibilityIdentifier("godkjenn.autentiserer")
                } else {
                    Button(action: onBekreft) {
                        Text(godkjenner ? "Godkjenn" : "Avslå").skrift(.knapp)
                    }
                    .buttonStyle(KnappStil(rolle: godkjenner ? .handling : .sekundar))
                    .accessibilityLabel(godkjenner ? "Godkjenn og bekreft med Face ID eller kode" : "Avslå forespørselen")
                    .accessibilityIdentifier("godkjenn.bekreft")
                }
                Button(action: onAvbryt) {
                    Text("Avbryt").skrift(.knapp)
                }
                .buttonStyle(KnappStil(rolle: .stille))
                .accessibilityLabel("Avbryt")
                .accessibilityIdentifier("godkjenn.avbryt")
            }
        }
        .padding(Theme.Avstand.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Bakgrunn())
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
        #endif
    }

    private var tekstFlate: some View {
        Text(forespørsel.tekst)
            .skrift(.tekst).foregroundStyle(Color(Theme.palett(for: scheme).tekst))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Avstand.s4)
            .textSelection(.enabled)
    }

    private func ramme<V: View>(_ innhold: V) -> some View {
        let p = Theme.palett(for: scheme)
        let form = RoundedRectangle(cornerRadius: Theme.Radius.band, style: .continuous)
        return innhold
            .background(form.fill(Color(p.band)))
            .overlay(form.strokeBorder(Color(p.kant), lineWidth: 1))
            .clipShape(form)
    }

    private var konsekvens: String {
        godkjenner ? "Godkjenn utfører handlingen nå." : "Avslå forkaster forespørselen."
    }
}

/// Raden over kortene når et svar ikke gikk som tenkt (rød lampe + ORD + melding, aldri farge alene), eller en stille
/// kvittering når det gikk. Lever utenfor brikken: etter «usikkert» kan kortet være borte, og meldingen skal stå igjen.
struct SvarRad: View {
    enum Innhold {
        /// Noe gikk galt. `oppdater`: knappen henter Nå på nytt (usikkert); ellers «Lukk».
        case avvik(SvarVisning, oppdater: Bool, kreverNyttToken: Bool)
        case kvittering(ord: String, tekst: String)
    }

    var innhold: Innhold
    var onOppdater: () -> Void
    var onLukk: () -> Void
    var onKobleTilPaaNytt: (() -> Void)?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        switch innhold {
        case .kvittering(let ord, let tekst):
            Band(etikett: ord, verdi: tekst, etikettDempet: true)
                .accessibilityIdentifier("godkjenn.kvittering")
        case .avvik(let visning, let oppdater, let nyttToken):
            Brikke {
                VStack(alignment: .leading, spacing: Theme.Avstand.s3) {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Avstand.s3) {
                        Circle().fill(Color(p.feil)).frame(width: Theme.Maal.led, height: Theme.Maal.led)
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                        Text(visning.ord).skrift(.status).foregroundStyle(Color(p.feil))
                            .accessibilityIdentifier("godkjenn.feilOrd")
                        Spacer(minLength: 0)
                    }
                    Text(visning.melding).skrift(.tekst).foregroundStyle(Color(p.tekst))
                        .fixedSize(horizontal: false, vertical: true)
                    if nyttToken, let onKobleTilPaaNytt {
                        Button(action: onKobleTilPaaNytt) { Text("Koble til på nytt").skrift(.knapp) }
                            .buttonStyle(KnappStil(rolle: .handling))
                            .accessibilityIdentifier("godkjenn.feilKobleTilPaaNytt")
                    } else {
                        Button(action: oppdater ? onOppdater : onLukk) {
                            Text(oppdater ? "Oppdater" : "Lukk").skrift(.knapp)
                        }
                        .buttonStyle(KnappStil(rolle: .sekundar))
                        .accessibilityIdentifier(oppdater ? "godkjenn.feilOppdater" : "godkjenn.feilLukk")
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(visning.ord.lowercased()). \(visning.melding)")
            .accessibilityIdentifier("godkjenn.feil")
        }
    }
}
