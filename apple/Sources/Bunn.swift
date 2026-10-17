import SwiftUI
import AppCore

/// Bunnen som er lik på alle skjermer: tab-bar og fot (versjon og kilde, identitet regel 9). Flyttet ut av `NaaView`
/// uendret, så «Tråder» får nøyaktig samme fot.
struct BunnView: View {
    var valgt: Hovedfane
    var onVelg: (Hovedfane) -> Void
    var kildeNavn: String
    var smaltKildeNavn: String
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let p = Theme.palett(for: scheme)
        VStack(spacing: Theme.Avstand.s3) {
            Tabbar(valgt: valgt, onVelg: onVelg)
            fot(p)
                .padding(.horizontal, Theme.Avstand.s1)
        }
        .padding(.horizontal, Theme.Avstand.s4)
        .padding(.top, Theme.Avstand.s3)
        .padding(.bottom, Theme.Avstand.s2)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            // Heldekkende under tab-baren (ingen tekst skal kunne ligge lesbar bak den, heller ikke når fot og fane er høye
            // i AX-størrelsene), og en FAST kort overgang over den, så innholdet blekner i stedet for å kuttes. Overgangen
            // har fast høyde: som andel av en høy bunn ble den et bredt, gjennomsiktig belte.
            ZStack(alignment: .top) {
                Color(p.flateBunn)
                LinearGradient(colors: [Color(p.flateBunn).opacity(0), Color(p.flateBunn)], startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.overgang)
                    .offset(y: -Self.overgang)
            }
            .ignoresSafeArea(edges: .bottom)
            // Overgangen ligger UTENFOR bunnens ramme (offset): uten dette fanger den berøringer over fanene
            // (Godkjenn, rulledrag).
            .allowsHitTesting(false)
        }
    }

    /// Høyden på den faste overgangen over bunnen. Skjermene legger `overgang + s2` under siste element, så det
    /// scroller helt fri av overgangen.
    static let overgang: CGFloat = 28
    static var luftUnder: CGFloat { overgang + Theme.Avstand.s2 }

    /// «huginn bygg <sha> <klokkeslett>»: hvilken kode som kjører (identitet regel 9). Tiden er byggetidspunktet, ikke nå.
    /// `brytende`: tillatt å brekke til flere linjer (stablet fot); ellers én linje i sin naturlige bredde.
    private func versjonTekst(_ p: Theme.Palette, brytende: Bool) -> some View {
        Text("huginn bygg \(BuildInfo.version)").skrift(.fot).foregroundStyle(Color(p.dempet))
            // Versjonslinja er en kontroll, ikke innhold: den vokser ikke forbi xxLarge (ved AX5 tok den tre linjer).
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .lineLimit(brytende ? nil : 1)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: brytende ? .infinity : nil, alignment: .leading)
            .accessibilityIdentifier("versionLabel")
    }

    private func kildeTekst(_ tekst: String, _ p: Theme.Palette, naturlig: Bool = false) -> some View {
        Text(tekst).skrift(.fot).foregroundStyle(Color(p.dempet)).lineLimit(1).truncationMode(.middle)
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .fixedSize(horizontal: naturlig, vertical: true)
            .accessibilityLabel(kildeNavn)
            .accessibilityIdentifier("naaKilde")
    }

    /// Versjonen kan ALDRI havne utenfor skjermen eller kuttes (regel 9). Rekkefølge:
    /// 1. side om side, full kilde-linje («live · ygg-v1»); 2. side om side, bare verten («ygg-v1»);
    /// 3. stablet: versjonen over, kilde-linja under, begge venstrestilt, og versjonen får brekke i stedet for å flyte ut.
    /// Fra og med tilgjengelighetsstørrelsene (AX1) er det alltid 3: da er monoteksten bredere enn en smal skjerm.
    @ViewBuilder private func fot(_ p: Theme.Palette) -> some View {
        if typeSize.isAccessibilitySize {
            stablet(p)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Avstand.s3) {
                    versjonTekst(p, brytende: false).fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    kildeTekst(kildeNavn, p, naturlig: true)
                }
                HStack(spacing: Theme.Avstand.s3) {
                    versjonTekst(p, brytende: false).fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    kildeTekst(smaltKildeNavn, p, naturlig: true)
                }
                stablet(p)
            }
        }
    }

    private func stablet(_ p: Theme.Palette) -> some View {
        VStack(alignment: .leading, spacing: Theme.Avstand.s1) {
            versjonTekst(p, brytende: true)
            kildeTekst(kildeNavn, p).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
