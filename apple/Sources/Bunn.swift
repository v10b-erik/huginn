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
        .background(
            // Heldekkende under tab-baren; en kort overgang over, så innholdet blekner i stedet for å kuttes.
            LinearGradient(
                stops: [.init(color: Color(p.flateBunn).opacity(0), location: 0), .init(color: Color(p.flateBunn), location: 0.14)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    /// «huginn bygg <sha> <klokkeslett>»: hvilken kode som kjører (identitet regel 9). Tiden er byggetidspunktet, ikke nå.
    /// `brytende`: tillatt å brekke til flere linjer (stablet fot); ellers én linje i sin naturlige bredde.
    private func versjonTekst(_ p: Theme.Palette, brytende: Bool) -> some View {
        Text("huginn bygg \(BuildInfo.version)").skrift(.fot).foregroundStyle(Color(p.dempet))
            .lineLimit(brytende ? nil : 1)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: brytende ? .infinity : nil, alignment: .leading)
            .accessibilityIdentifier("versionLabel")
    }

    private func kildeTekst(_ tekst: String, _ p: Theme.Palette, naturlig: Bool = false) -> some View {
        Text(tekst).skrift(.fot).foregroundStyle(Color(p.dempet)).lineLimit(1).truncationMode(.middle)
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
