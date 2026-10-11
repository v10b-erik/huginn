import SwiftUI
import AppCore

/// Godkjenningsbrikken: den ene tingen som krever en handling. Fylt flate = handling (Godkjenn); resten er tone.
/// `onSvar == nil` deaktiverer begge knappene (ingen skriveveier): en høyrisikoknapp som halvveis virker er verre enn
/// en som er av. Et trykk åpner bare bekreftelsen; ingenting sendes fra brikken.
struct GodkjenningBrikke: View {
    /// Hva knappene gjør akkurat nå.
    enum Knapper {
        case aktive
        /// Av, men synlige: noe annet pågår (en annen forsendelse, systemdialogen) eller en usikkerhet venter på kvittering.
        case av
        /// Dette kortets svar er ute. Knappene byttes mot en tonet «Sender …» (tone/kant = pågår, ingen spinner).
        case sender
    }

    var godkjenning: NaaSkjerm.Godkjenning
    var onSvar: ((NaaSkjerm.Handling) -> Void)?
    var knapper: Knapper = .aktive
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
                if knapper == .sender {
                    sender(p)
                        .padding(.top, Theme.Avstand.s3)
                } else {
                    Proporsjonal(vekter: [3, 2], mellomrom: Theme.Avstand.s2) {
                        Button { onSvar?(godkjenning.godkjenn) } label: {
                            Text("Godkjenn").skrift(.knapp)
                        }
                        .buttonStyle(KnappStil(rolle: .handling))
                        .accessibilityLabel("Godkjenn: \(forsteLinje)")
                        .accessibilityIdentifier("godkjennKnapp" + idSuffiks)

                        Button { onSvar?(godkjenning.avslaa) } label: {
                            Text("Avslå").skrift(.knapp)
                        }
                        .buttonStyle(KnappStil(rolle: .sekundar))
                        .accessibilityLabel("Avslå: \(forsteLinje)")
                        .accessibilityIdentifier("avslaaKnapp" + idSuffiks)
                    }
                    .disabled(onSvar == nil || knapper == .av)
                    .opacity(onSvar == nil || knapper == .av ? 0.45 : 1)
                    .padding(.top, Theme.Avstand.s3)
                }
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
        return l.isEmpty ? godkjenning.tittel : l
    }

    fileprivate var forsteLinje: String {
        let l = NaaSkjerm.Godkjenning.forsteLinje(godkjenning.tittel)
        return l.isEmpty ? "godkjenning" : l
    }

    /// «Sender …»: pågår = tone og kant i aksent (regel 2), uten spinner og uten blinking. Ordet bærer tilstanden (regel 4).
    fileprivate func sender(_ p: Theme.Palette) -> some View {
        let form = RoundedRectangle(cornerRadius: Theme.Radius.knapp, style: .continuous)
        return Text("Sender …").skrift(.knapp)
            .foregroundStyle(Color(p.aksent))
            .frame(maxWidth: .infinity, minHeight: Theme.Maal.knapp)
            .background(form.fill(Color(p.aksentTone)))
            .overlay(form.strokeBorder(Color(p.aksentKant), lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sender svar: \(forsteLinje)")
            .accessibilityIdentifier("godkjenn.sender" + idSuffiks)
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
