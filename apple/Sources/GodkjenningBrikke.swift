import SwiftUI
import AppCore

/// Godkjenningsbrikken: den ene tingen som krever en handling. Fylt flate = handling (Godkjenn); resten er tone.
/// `onSvar == nil` deaktiverer begge knappene (live-modus har ingen skriveveier ennå): en høyrisikoknapp som
/// halvveis virker er verre enn en som er av.
struct GodkjenningBrikke: View {
    var godkjenning: NaaSkjerm.Godkjenning
    var onSvar: ((NaaSkjerm.Handling) -> Void)?
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
                Text(godkjenning.tittel).skrift(.h2).foregroundStyle(Color(p.tekst))
                    .padding(.bottom, Theme.Avstand.s1)
                    .accessibilityAddTraits(.isHeader)
                if let kilde = godkjenning.kilde {
                    Band(etikett: "Fra", verdi: kilde,
                         ord: godkjenning.kildeRen == true ? "Rent" : nil, ordTone: .ok)
                }
                if let klasse = godkjenning.klasse {
                    Band(etikett: "Klasse", verdi: klasse)
                }
                Proporsjonal(vekter: [3, 2], mellomrom: Theme.Avstand.s2) {
                    Button { onSvar?(godkjenning.godkjenn) } label: {
                        Text("Godkjenn").skrift(.knapp)
                    }
                    .buttonStyle(KnappStil(rolle: .handling))
                    .accessibilityIdentifier("godkjennKnapp" + idSuffiks)

                    Button { onSvar?(godkjenning.avslaa) } label: {
                        Text("Avslå").skrift(.knapp)
                    }
                    .buttonStyle(KnappStil(rolle: .sekundar))
                    .accessibilityIdentifier("avslaaKnapp" + idSuffiks)
                }
                .disabled(onSvar == nil)
                .opacity(onSvar == nil ? 0.45 : 1)
                .padding(.top, Theme.Avstand.s3)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("naaKreverBrikke" + idSuffiks)
    }
}

/// Knappene (radius `knapp`, høyde `Maal.knapp`). Handling = fylt periwinkle; sekundær = glass.
struct KnappStil: ButtonStyle {
    enum Rolle { case handling, sekundar }
    var rolle: Rolle
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        let p = Theme.palett(for: scheme)
        let form = RoundedRectangle(cornerRadius: Theme.Radius.knapp, style: .continuous)
        configuration.label
            .foregroundStyle(rolle == .handling ? Color(p.paAksent) : Color(p.tekst))
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
                }
            }
            .contentShape(form)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: Theme.Varighet.knapp), value: configuration.isPressed)
    }
}
