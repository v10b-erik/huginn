import SwiftUI
import AppCore

/// Godkjenningsbrikken: den ene tingen som krever en handling. Fylt flate = handling (Godkjenn); resten er tone.
/// `onSvar == nil` deaktiverer begge knappene (ingen skriveveier): en høyrisikoknapp som halvveis virker er verre enn
/// en som er av. Et trykk åpner bare bekreftelsen; ingenting sendes fra brikken.
struct GodkjenningBrikke: View {
    /// Hva knappene gjør akkurat nå.
    enum Knapper: Equatable {
        case aktive
        /// Noe annet pågår (en annen forsendelse, systemdialogen) eller en usikkerhet venter på kvittering. Knappene er
        /// BORTE (ikke deaktiverte): en dempet, fylt Godkjenn ser ut som en knapp og bryter regel 2 og 10. Ordet «Venter på svar».
        case av
        /// Dette kortets svar er ute. Knappene byttes mot en tonet flate med teksten («Sender godkjenning …»): tone og
        /// kant = pågår (regel 2), ordet i vanlig tekstfarge (kontrast), ingen spinner.
        case sender(String)
        /// Dette kortets svar fikk ikke svar: rød lampe + ORD + melding, og Oppdater som eneste valg.
        case usikker(SvarVisning)
    }

    var godkjenning: NaaSkjerm.Godkjenning
    var onSvar: ((NaaSkjerm.Handling) -> Void)?
    var knapper: Knapper = .aktive
    var onOppdater: (() -> Void)?
    var idSuffiks = ""
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        Brikke(variant: .krever, padding: EdgeInsets(top: Theme.Avstand.s4, leading: Theme.Avstand.s4, bottom: Theme.Avstand.s4, trailing: Theme.Avstand.s4)) {
            VStack(alignment: .leading, spacing: Theme.Avstand.s2) {
                HStack {
                    Text("Godkjenning").skrift(.etikettAksent).foregroundStyle(Color(p.aksent))
                    Spacer()
                    if let opprettet = godkjenning.opprettet {
                        // Tikker hvert sekund; selve tiden er ren funksjon i AppCore.
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            Text(Tid.klokke(sekunder: Int(ctx.date.timeIntervalSince(opprettet))))
                                .skrift(.etikett).monospacedDigit().foregroundStyle(Color(p.dempet))
                        }
                        .accessibilityHidden(true)
                    }
                }
                // Brikken viser målet (første linje, maks tre linjer); HELE teksten står i bekreftelsen, som alltid kommer
                // før noe kan sendes.
                Text(forsteLinjeEllerTittel).skrift(.h2).foregroundStyle(Color(p.tekst))
                    .lineLimit(3)
                    .padding(.bottom, Theme.Avstand.s1)
                    .accessibilityAddTraits(.isHeader)
                if let kilde = godkjenning.kilde {
                    Band(etikett: "Fra", verdi: kilde,
                         ord: godkjenning.kildeRen == true ? "Rent" : nil, ordTone: .ok)
                }
                if let klasse = godkjenning.klasse {
                    Band(etikett: "Klasse", verdi: klasse)
                }
                bunn(p)
                    .padding(.top, Theme.Avstand.s3)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("naaKreverBrikke" + idSuffiks)
    }
}

extension GodkjenningBrikke {
    /// Kortets første linje, til VoiceOver (aldri token: brikken kjenner ikke tokenet).
    fileprivate var forsteLinjeEllerTittel: String {
        let l = NaaSkjerm.Godkjenning.forsteLinje(godkjenning.tittel)
        return l.isEmpty ? Svar.Forespørsel.rens(godkjenning.tittel) : l
    }

    fileprivate var forsteLinje: String {
        let l = NaaSkjerm.Godkjenning.forsteLinje(godkjenning.tittel)
        return l.isEmpty ? "godkjenning" : l
    }

    /// Det som står under kortet: knapper, «Sender …», «Venter på svar» eller usikkerheten.
    @ViewBuilder fileprivate func bunn(_ p: Theme.Palette) -> some View {
        switch knapper {
        case .aktive:
            knapperad
        case .av:
            Text("Venter på svar").skrift(.status).foregroundStyle(Color(p.dempet))
                .frame(maxWidth: .infinity, minHeight: Theme.Maal.knapp)
                .accessibilityIdentifier("godkjenn.venter" + idSuffiks)
        case .sender(let tekst):
            sender(tekst, p)
        case .usikker(let visning):
            usikker(visning, p)
        }
    }

    @ViewBuilder fileprivate var knapperad: some View {
        Proporsjonal(vekter: [3, 2], mellomrom: Theme.Avstand.s2) {
            if let godkjenn = godkjenning.godkjenn {
                Button { onSvar?(godkjenn) } label: {
                    Text(godkjenn.label).skrift(.knapp)
                }
                .buttonStyle(KnappStil(rolle: .handling))
                .accessibilityLabel("\(godkjenn.label): \(forsteLinje)")
                .accessibilityIdentifier("godkjennKnapp" + idSuffiks)
            } else {
                // Kortet har flere handlinger enn appen kan bære: ingen Godkjenn-vei, bare ordene (ikke en knapp).
                FlereValg()
                    .accessibilityIdentifier("godkjenn.flereValg" + idSuffiks)
            }
            Button { onSvar?(godkjenning.avslaa) } label: {
                Text("Avslå").skrift(.knapp)
            }
            .buttonStyle(KnappStil(rolle: .sekundar))
            .accessibilityLabel("Avslå: \(forsteLinje)")
            .accessibilityIdentifier("avslaaKnapp" + idSuffiks)
        }
        .disabled(onSvar == nil)
        .opacity(onSvar == nil ? 0.45 : 1)
    }

    /// «Sender …»: pågår = tone og kant i aksent (regel 2), uten spinner og uten blinking. Ordet står i tekstfarge
    /// (aksent på aksenttone ga 3,6:1 i lys modus) og bærer tilstanden (regel 4).
    fileprivate func sender(_ tekst: String, _ p: Theme.Palette) -> some View {
        let form = RoundedRectangle(cornerRadius: Theme.Radius.knapp, style: .continuous)
        return Text(tekst).skrift(.knapp)
            .foregroundStyle(Color(p.tekst))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: Theme.Maal.knapp)
            .padding(.horizontal, Theme.Avstand.s3)
            .background(form.fill(Color(p.aksentTone)))
            .overlay(form.strokeBorder(Color(p.aksentKant), lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(tekst) \(forsteLinje)")
            .accessibilityIdentifier("godkjenn.sender" + idSuffiks)
    }

    /// Rød lampe + ORD + melding, og Oppdater som eneste handlingsvalg. Inne i kortet, så kortet ikke skyves ned.
    fileprivate func usikker(_ v: SvarVisning, _ p: Theme.Palette) -> some View {
        VStack(alignment: .leading, spacing: Theme.Avstand.s3) {
            HStack(spacing: Theme.Avstand.s3) {
                Circle().fill(Color(p.feil)).frame(width: Theme.Maal.led, height: Theme.Maal.led)
                // Lampen er rød (avvik); ordet står i tekstfarge: rød tekst på kortets tone gir 4,19:1 i lys modus (< 4,5).
                Text(v.ord).skrift(.status).foregroundStyle(Color(p.tekst))
                    .accessibilityIdentifier("godkjenn.feilOrd")
                Spacer(minLength: 0)
            }
            Text(v.melding).skrift(.tekst).foregroundStyle(Color(p.tekst))
                .fixedSize(horizontal: false, vertical: true)
            Button { onOppdater?() } label: { Text("Oppdater").skrift(.knapp) }
                .buttonStyle(KnappStil(rolle: .sekundar))
                .accessibilityIdentifier("godkjenn.feilOppdater")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("godkjenn.feil" + idSuffiks)
    }
}

/// «FLERE VALG · SVAR I TELEGRAM»: dempet tekst, ikke en knapp.
private struct FlereValg: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text("Flere valg · svar i Telegram").skrift(.status)
            .foregroundStyle(Color(Theme.palett(for: scheme).dempet))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: Theme.Maal.knapp, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Flere valg. Svar i Telegram.")
    }
}

/// Knappene (radius `knapp`, høyde `Maal.knapp`). Handling = fylt periwinkle; sekundær = glass.
struct KnappStil: ButtonStyle {
    /// `stille`: ingen flate, bare dempet tekst (f.eks. «Prøv demo»); minst like høy som de andre (berøringsmål).
    /// `deaktivert`: en handling som ennå ikke kan brukes. Bæres av FORM (ingen fyll, ingen lyskant, bare en strek),
    /// med dempet tekst i full dekkevne (aldri en blek utgave av den aktive).
    enum Rolle { case handling, sekundar, stille, deaktivert }
    var rolle: Rolle
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        let p = Theme.palett(for: scheme)
        let form = RoundedRectangle(cornerRadius: Theme.Radius.knapp, style: .continuous)
        configuration.label
            .foregroundStyle(rolle == .handling ? Color(p.paAksent) : (rolle == .stille || rolle == .deaktivert) ? Color(p.dempet) : Color(p.tekst))
            .frame(maxWidth: .infinity, minHeight: Theme.Maal.knapp)
            .background {
                switch rolle {
                case .handling:
                    form.fill(LinearGradient(colors: [Color(p.aksentFyll1), Color(p.aksentFyll2)], startPoint: .top, endPoint: .bottom))
                        .overlay(form.strokeBorder(Color(p.paAksent).opacity(0.22), lineWidth: 1))
                        .overlay(form.inset(by: 1).strokeBorder(Color(p.paAksent).opacity(0.2), lineWidth: 1)
                            .mask(alignment: .top) {
                                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: Theme.Radius.knapp)
                            })
                        .shadow(color: Color(p.aksentFyll2).opacity(0.55), radius: 8, x: 0, y: 6)
                case .sekundar:
                    Color.clear.glassFlate(radius: Theme.Radius.knapp)
                case .stille:
                    Color.clear
                case .deaktivert:
                    form.strokeBorder(Color(p.kant), lineWidth: 1)
                }
            }
            .contentShape(form)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: Theme.Varighet.knapp), value: configuration.isPressed)
    }
}
