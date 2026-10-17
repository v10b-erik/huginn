import SwiftUI
import AppCore

/// Heroen: punktmatrise-tallet sier hva som krever deg. Tre tilstander (identitet regel 3): «KREVER DEG» med tallet,
/// «INGEN OPPGAVER» (grått 0 og «N avvik») når bare avvik finnes, og «ALT ROLIG» (grått 0) når ingenting er galt.
struct HeroView: View {
    enum Visning {
        case krever(Int)
        case rolig
        /// Ingenting krever deg, men det finnes avvik: grått 0 som rolig, undertekst «N avvik» (ordet bærer meningen).
        case ingenOppgaver
        /// Før vi vet noe: slukket felt, ingen tall (et 0 her ville vært en løgn).
        case laster
    }

    var visning: Visning
    var tittel: String
    var undertekst: String
    /// VoiceOver-teksten fra `NaaSkjerm.heroTale`; `nil` = utledet her (bare «laster»).
    var tale: String?
    @Environment(\.colorScheme) private var scheme
    @State private var kolonneBredde: CGFloat = 0
    @State private var ordBredde: CGFloat = 0

    /// Det bredeste ordet heroen kan sette i tittelen («Ingen oppgaver»). Setter størrelsen for alle tilstandene.
    static let bredesteOrd = "OPPGAVER"
    /// Gulvet (0,3) rekker til de største tekststørrelsene på en smal skjerm; under det kuttes «OPPGAVER» heller enn å bli uleselig.
    static let minSkala: CGFloat = 0.3
    /// Luft (4 %) så ordet aldri står nøyaktig på kanten: fonter skalerer ikke helt lineært, og et ord som er 1 pt for bredt kuttes («OPPGAV…»).
    static let margin: CGFloat = 0.96

    /// Skalaen som gir det bredeste ordet plass i kolonnen: aldri større enn tokenet, aldri under gulvet, og INGEN
    /// avhengighet av tilstanden. Ukjent bredde (før første måling) gir full størrelse.
    static func skala(kolonne: CGFloat, ord: CGFloat) -> CGFloat {
        guard kolonne > 0, ord > 0 else { return 1 }
        return min(1, max(minSkala, kolonne / ord * margin))
    }

    /// Tittelstilen: heroen-stilen fra tokens, skalert likt (størrelse og linjehøyde) for alle tilstander.
    static func tittelStil(skala: CGFloat) -> SkriftStil {
        typealias T = Theme.Typografi
        return SkriftStil(
            familie: .visningBold, str: T.Str.hero * skala, linjehoyde: T.Lh.hero * skala,
            sperring: T.Sperring.hero, relativTil: .largeTitle, versaler: true
        )
    }

    private var skala: CGFloat { Self.skala(kolonne: kolonneBredde, ord: ordBredde) }

    var body: some View {
        let p = Theme.palett(for: scheme)
        Brikke(padding: EdgeInsets(top: Theme.Avstand.s5, leading: Theme.Avstand.s5, bottom: Theme.Avstand.s5, trailing: Theme.Avstand.s5)) {
            HStack(spacing: Theme.Avstand.s5) {
                LCDTall(
                    tekst: lcdTekst, pitch: lcdTekst.count > 1 ? Theme.Lcd.pitchHero * 0.7 : Theme.Lcd.pitchHero,
                    lys: lysFarge(p), slukket: Color(p.spor),
                    glod: glod ? Color(p.aksent).opacity(0.5) : nil
                )
                VStack(alignment: .leading, spacing: Theme.Avstand.s3) {
                    // Usynlig, null høyde: gir kolonnen all ledig bredde, og måler den.
                    Color.clear.frame(maxWidth: .infinity, minHeight: 0, maxHeight: 0)
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { kolonneBredde = $0 }
                    // ÉN skriftstørrelse for tittelen i alle tilstander: den som gir «OPPGAVER» (det bredeste ordet)
                    // plass i kolonnen. Ingen tilstand krymper for seg selv, så heroen ser ut som samme komponent.
                    Text(tittel.replacingOccurrences(of: " ", with: "\n"))
                        .skrift(Self.tittelStil(skala: skala))
                        .foregroundStyle(krever ? Color(p.tekst) : Color(p.dempet))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    // Én linje i alle tilstander. Lange tekster («Ingenting venter på deg») krymper litt, og krympingen
                    // gjør linja lavere; den usynlige referansen holder høyden lik (ellers 1 pt lavere hero i «Alt rolig»).
                    ZStack(alignment: .topLeading) {
                        Text("A").skrift(.etikettAksent).hidden().accessibilityHidden(true)
                        Text(undertekst)
                            .skrift(.etikettAksent)
                            .foregroundStyle(krever ? Color(p.aksent) : Color(p.dempet))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: Double(Punktmatrise.rader) * Theme.Lcd.pitchHero)
            // Det bredeste tittelordet i full størrelse, usynlig og utenfor layouten: bare for å måle.
            .overlay(alignment: .topLeading) {
                Text(Self.bredesteOrd).skrift(.hero).fixedSize().hidden().accessibilityHidden(true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { ordBredde = $0 }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(etikett)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("naaHero")
    }

    private var krever: Bool { if case .krever = visning { true } else { false } }
    private var glod: Bool { scheme == .dark && krever }

    private var lcdTekst: String {
        switch visning {
        case .krever(let n): String(min(max(n, 0), 99))
        case .rolig, .ingenOppgaver: "0"
        case .laster: " "
        }
    }

    private func lysFarge(_ p: Theme.Palette) -> Color {
        // `dempet`, ikke `svak`: svak er ikke tekstfarge, og tallet er signaturen (regel 10).
        krever ? Color(p.aksent) : Color(p.dempet)
    }

    /// VoiceOver leser meningen, ikke prikkene. Teksten kommer fra `NaaSkjerm.heroTale` (én kilde); bare «laster» har ingen.
    private var etikett: String { tale ?? "Henter. \(undertekst)" }
}

/// Chippen øverst til høyre: lampe + ord (aldri farge alene). Den bærer tilstanden til tilkoblingen når «Nå» ikke
/// har data (henter, får ikke kontakt, ikke innlogget), ellers plattformstatusen.
struct StatusChip: View {
    var lampe: Kontakt.Lampe
    var tekst: String
    var etikett: String
    /// Fylt aksentlampe uten å være ok/avvik: noe krever deg (f.eks. «2 venter» på Tråder).
    var aksentLampe = false
    var id = "naaStatusChip"
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        HStack(spacing: Theme.Avstand.s2) {
            switch lampe {
            case .ingen where aksentLampe: Circle().fill(Color(p.aksent)).frame(width: Theme.Maal.led, height: Theme.Maal.led)
            case .ok: Circle().fill(Color(p.ok)).frame(width: Theme.Maal.led, height: Theme.Maal.led)
            case .avvik: Circle().fill(Color(p.feil)).frame(width: Theme.Maal.led, height: Theme.Maal.led)
            case .ingen: EmptyView()
            }
            Text(tekst).skrift(.etikett).foregroundStyle(Color(p.tekst)).lineLimit(1)
        }
        .padding(.horizontal, Theme.Avstand.s3)
        .padding(.vertical, Theme.Avstand.s2)
        .frame(minHeight: Theme.Maal.beroringMin)
        .glassFlate(radius: Theme.Radius.chip)
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(etikett)
        .accessibilityIdentifier(id)
    }
}
