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
                    // «OPPGAVER» er det bredeste ordet: det krymper litt (aldri brytes midt i ordet) i stedet for å
                    // gi en tredje linje. Krympingen gjør to linjer lavere, så en usynlig toLinjers referanse i samme
                    // stil setter høyden: heroen er like høy i alle tre tilstandene og innholdet under hopper ikke.
                    ZStack(alignment: .topLeading) {
                        Text("A\nA").skrift(.hero).hidden().accessibilityHidden(true)
                        Text(tittel.replacingOccurrences(of: " ", with: "\n"))
                            .skrift(.hero)
                            .foregroundStyle(krever ? Color(p.tekst) : Color(p.dempet))
                            .lineLimit(2)
                            .minimumScaleFactor(0.5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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

    /// VoiceOver leser meningen, ikke prikkene.
    private var etikett: String {
        if let tale { return tale }
        switch visning {
        case .krever(let n): return "\(n) krever deg. \(undertekst)"
        case .rolig: return "Alt rolig. \(undertekst)"
        case .ingenOppgaver: return "Ingen oppgaver. \(undertekst)"
        case .laster: return "Henter. \(undertekst)"
        }
    }
}

/// Chippen øverst til høyre: lampe + ord (aldri farge alene). Den bærer tilstanden til tilkoblingen når «Nå» ikke
/// har data (henter, får ikke kontakt, ikke innlogget), ellers plattformstatusen.
struct StatusChip: View {
    var lampe: Kontakt.Lampe
    var tekst: String
    var etikett: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        HStack(spacing: Theme.Avstand.s2) {
            switch lampe {
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
        .accessibilityIdentifier("naaStatusChip")
    }
}
