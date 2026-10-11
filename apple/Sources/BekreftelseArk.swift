import SwiftUI
import AppCore

/// Bekreftelsen før Godkjenn/Avslå. Viser hva som bestemmes (overskrift, risikobåndene fra brikken, HELE teksten rullbar,
/// og hva som skjer) og knappene. Sender ingenting selv: «Godkjenn» her starter systemets autentisering (en egen dialog),
/// og først etter den sendes noe.
///
/// Identiteten: handlingen står med kortets egen etikett («✉️ Send», «Godkjenn» for `approve`). Godkjenn er den fylte flaten
/// (handling), Avslå er glass, Avbryt er stille. Konsekvensen står som ord (regel 4), ikke som farge.
/// Høyden følger innholdet (`presentationDetents`), og lang tekst ruller i stedet for å skyve knappene ut.
struct BekreftelseArk: View {
    var forespørsel: Svar.Forespørsel
    /// Systemets dialog er oppe: knappen er av og sier fra (tone/kant, ingen spinner).
    var autentiserer: Bool
    var onBekreft: () -> Void
    var onAvbryt: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var hoyde: CGFloat = 0
    /// Starter lavt og går til innholdets høyde når den er målt (uten dette åpnet arket på `.large` og ble stående der).
    @State private var valgt: PresentationDetent = .medium

    private var godkjenner: Bool { !forespørsel.valg.erAvslag }

    var body: some View {
        innhold(rull: true)
            // Samme innhold uten rulling, usynlig, bare for å måle hvor høyt det vil være.
            .background(alignment: .top) {
                innhold(rull: false)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { hoyde = $0 }
            }
            .background(Bakgrunn())
            #if os(iOS)
            .presentationDetents(hoyde > 0 ? [.height(hoyde + 8), .large] : [.medium, .large], selection: $valgt)
            .onChange(of: hoyde) { _, h in if valgt != .large { valgt = .height(h + 8) } }
            .presentationDragIndicator(.visible)
            #else
            .frame(minWidth: 420, minHeight: 360)
            #endif
    }

    private func innhold(rull: Bool) -> some View {
        let p = Theme.palett(for: scheme)
        return VStack(alignment: .leading, spacing: Theme.Avstand.s3) {
            Text(forespørsel.valg.label)
                .skrift(.etikettAksent).foregroundStyle(Color(godkjenner ? p.aksent : p.dempet))
                .accessibilityIdentifier("godkjenn.handling")
            Text(forespørsel.forsteLinje).skrift(.h2).foregroundStyle(Color(p.tekst))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("godkjenn.tittel")

            // Det brikken viser: hvem som ber om det og hvor risikabelt, der man bestemmer seg.
            if let kilde = forespørsel.kilde {
                Band(etikett: "Fra", verdi: kilde, ord: forespørsel.kildeRen == true ? "Rent" : nil, ordTone: .ok)
                    .accessibilityIdentifier("godkjenn.fra")
            }
            if let klasse = forespørsel.klasse {
                Band(etikett: "Klasse", verdi: klasse)
                    .accessibilityIdentifier("godkjenn.klasse")
            }

            // Resten av kortteksten (overskriften er første linje): hele teksten er overskrift + dette.
            let rest = forespørsel.rest
            if !rest.isEmpty {
                if rull {
                    ViewThatFits(in: .vertical) {
                        ramme(restFlate(rest))
                        ramme(ScrollView { restFlate(rest) })
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityLabel(rest)
                    .accessibilityIdentifier("godkjenn.tekst")
                } else {
                    ramme(restFlate(rest))
                }
            }

            konsekvensFlate(p)

            VStack(spacing: Theme.Avstand.s2) {
                if autentiserer {
                    Text("Bekrefter …").skrift(.knapp)
                        .foregroundStyle(Color(p.tekst))
                        .frame(maxWidth: .infinity, minHeight: Theme.Maal.knapp)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.knapp, style: .continuous).fill(Color(p.aksentTone)))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.knapp, style: .continuous).strokeBorder(Color(p.aksentKant), lineWidth: 1))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Bekrefter at det er deg")
                        .accessibilityIdentifier("godkjenn.autentiserer")
                } else {
                    Button(action: onBekreft) {
                        Text(forespørsel.valg.label).skrift(.knapp)
                    }
                    .buttonStyle(KnappStil(rolle: godkjenner ? .handling : .sekundar))
                    .accessibilityLabel(godkjenner ? "\(forespørsel.valg.label), bekreft med Face ID eller kode" : "Avslå forespørselen")
                    .accessibilityIdentifier("godkjenn.bekreft")
                }
                Button(action: onAvbryt) {
                    Text("Avbryt").skrift(.knapp)
                }
                .buttonStyle(KnappStil(rolle: .stille))
                .accessibilityLabel("Avbryt")
                .accessibilityIdentifier("godkjenn.avbryt")
            }
            .padding(.top, Theme.Avstand.s1)
        }
        .padding(Theme.Avstand.s5)
        .frame(maxWidth: .infinity, maxHeight: rull ? .infinity : nil, alignment: .topLeading)
    }

    private func restFlate(_ rest: String) -> some View {
        Text(rest)
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

    /// «Hva skjer»: konkret, med handlingens egen etikett. Fri høyde (ingen linjegrense: teksten kuttes aldri).
    private func konsekvensFlate(_ p: Theme.Palette) -> some View {
        let form = RoundedRectangle(cornerRadius: Theme.Radius.band, style: .continuous)
        return VStack(alignment: .leading, spacing: Theme.Avstand.s1) {
            Text("Hva skjer").skrift(.etikett).foregroundStyle(Color(p.dempet))
            Text(forespørsel.konsekvens).skrift(.tekst).foregroundStyle(Color(p.tekst))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.Avstand.s4)
        .padding(.vertical, Theme.Avstand.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(form.fill(Color(p.band)))
        .overlay(form.strokeBorder(Color(p.kant), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("godkjenn.konsekvens")
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

