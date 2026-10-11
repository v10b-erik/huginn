import SwiftUI
import AppCore

/// Heroen: punktmatrise-tallet sier hva som krever deg. Normal dag = et grått 0 og «ALT ROLIG».
struct HeroView: View {
    enum Visning {
        case krever(Int)
        case rolig
        /// Før vi vet noe: slukket felt, ingen tall (et 0 her ville vært en løgn).
        case laster
    }

    var visning: Visning
    var tittel: String
    var undertekst: String
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
                    Text(tittel.replacingOccurrences(of: " ", with: "\n"))
                        .skrift(.hero)
                        .foregroundStyle(krever ? Color(p.tekst) : Color(p.dempet))
                        .fixedSize(horizontal: false, vertical: true)
                    // Én linje i begge tilstander, så heroen er like høy og innholdet under ikke hopper.
                    Text(undertekst)
                        .skrift(.etikettAksent)
                        .foregroundStyle(krever ? Color(p.aksent) : Color(p.dempet))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
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
        case .rolig: "0"
        case .laster: " "
        }
    }

    private func lysFarge(_ p: Theme.Palette) -> Color {
        // `dempet`, ikke `svak`: svak er ikke tekstfarge, og tallet er signaturen (regel 10).
        krever ? Color(p.aksent) : Color(p.dempet)
    }

    /// VoiceOver leser meningen, ikke prikkene.
    private var etikett: String {
        switch visning {
        case .krever(let n): "\(n) krever deg. \(undertekst)"
        case .rolig: "Alt rolig. \(undertekst)"
        case .laster: "Henter. \(undertekst)"
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
