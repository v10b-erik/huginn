import SwiftUI
import AppCore

/// «Tråder»: lesevisning over trådene trådflata kjenner. Viewet tegner bare `TraadSkjerm`; ingen logikk bor her.
/// Fire tilstander som alltid tegnes: henter, feil, tom og liste. Ingen skriving, ingen handlinger i denne runden.
struct TraaderView: View {
    @State private var modell: TraaderModell
    private let kildeNavn: String
    private let smaltKildeNavn: String
    private let onKobleTilPaaNytt: (() -> Void)?
    private let onVelgFane: (Hovedfane) -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase

    init(
        kilde: any TraadKilde, kildeNavn: String, smaltKildeNavn: String? = nil,
        onKobleTilPaaNytt: (() -> Void)? = nil, onVelgFane: @escaping (Hovedfane) -> Void
    ) {
        _modell = State(initialValue: TraaderModell(kilde: kilde))
        self.kildeNavn = kildeNavn
        self.smaltKildeNavn = smaltKildeNavn ?? kildeNavn
        self.onKobleTilPaaNytt = onKobleTilPaaNytt
        self.onVelgFane = onVelgFane
    }

    private static let maksBredde: CGFloat = 560

    var body: some View {
        let p = Theme.palett(for: scheme)
        ScrollView {
            VStack(spacing: Theme.Avstand.s3) {
                Text("Tråder").skrift(.h2).foregroundStyle(Color(p.tekst))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Avstand.s1)
                    .padding(.bottom, Theme.Avstand.s1)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("traaderTittel")
                if let feil = modell.feil { feilBrikke(feil, p) }
                if let skjerm = modell.skjerm {
                    innhold(skjerm, p)
                } else if modell.feil == nil {
                    lasterBrikke(p)
                }
            }
            .padding(.horizontal, Theme.Avstand.s4)
            .padding(.top, Theme.Avstand.s4)
            .padding(.bottom, Theme.Avstand.s4)
            .frame(maxWidth: Self.maksBredde)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await modell.last() }
        .background(Bakgrunn())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BunnView(valgt: .traader, onVelg: onVelgFane, kildeNavn: kildeNavn, smaltKildeNavn: smaltKildeNavn)
        }
        .task { await modell.last() }
        .onChange(of: scenePhase) { _, ny in
            if ny == .active { Task { await modell.last() } }
        }
    }

    @ViewBuilder private func innhold(_ s: TraadSkjerm, _ p: Theme.Palette) -> some View {
        if s.rader.isEmpty {
            Brikke {
                Text(s.tomTekst).skrift(.tekst).foregroundStyle(Color(p.dempet))
                    .accessibilityIdentifier("traaderTom")
            }
        } else {
            Listebrikke(tittel: "Siste aktivitet", hoyre: "\(s.antall)", rader: s.rader, idPrefiks: "traaderListe")
            if s.kanVæreAvkortet {
                Text("Viser de \(TraadSkjerm.serverGrense) nyeste")
                    .skrift(.undertekst).foregroundStyle(Color(p.dempet))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Avstand.s1)
                    .accessibilityIdentifier("traaderAvkortet")
            }
        }
    }

    private func lasterBrikke(_ p: Theme.Palette) -> some View {
        Brikke {
            HStack(spacing: Theme.Avstand.s3) {
                ProgressView().controlSize(.small)
                Text("Henter tråder").skrift(.tekst).foregroundStyle(Color(p.dempet))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("traaderLaster")
    }

    private func feilBrikke(_ feil: NaaFeil, _ p: Theme.Palette) -> some View {
        Brikke {
            VStack(alignment: .leading, spacing: Theme.Avstand.s3) {
                HStack(spacing: Theme.Avstand.s3) {
                    Circle().fill(Color(p.feil)).frame(width: Theme.Maal.led, height: Theme.Maal.led)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(feil.tittel).skrift(.tekst).foregroundStyle(Color(p.tekst))
                        Text(feil.detalj).skrift(.undertekst).foregroundStyle(Color(p.dempet))
                    }
                    Spacer(minLength: Theme.Avstand.s2)
                    Text("FEIL").skrift(.status).foregroundStyle(Color(p.feil))
                }
                if feil.kreverNyttToken, let onKobleTilPaaNytt {
                    Button(action: onKobleTilPaaNytt) { Text("Koble til på nytt").skrift(.knapp) }
                        .buttonStyle(KnappStil(rolle: .handling))
                        .accessibilityIdentifier("traaderKobleTilPaaNytt")
                } else {
                    Button { Task { await modell.last() } } label: { Text("Prøv igjen").skrift(.knapp) }
                        .buttonStyle(KnappStil(rolle: .sekundar))
                        .disabled(modell.henter)
                        .accessibilityIdentifier("traaderForsoekIgjen")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("traaderFeil")
    }
}
