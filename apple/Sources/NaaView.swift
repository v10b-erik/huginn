import SwiftUI
import AppCore

/// «Nå»: det som venter på deg, og ingenting annet. Viewet tegner bare `NaaSkjerm`; ingen logikk bor her.
struct NaaView: View {
    @State private var modell: NaaModell
    private let kildeNavn: String
    private let onSvar: ((NaaSkjerm.Handling) -> Void)?
    private let onTilkobling: () -> Void
    private let onKobleTilPaaNytt: (() -> Void)?
    private let onKontakt: (Kontakt) -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase

    /// - Parameter onSvar: `nil` = Godkjenn/Avslå er synlige men deaktiverte (live-modus har ingen skriveveier).
    /// - Parameters:
    ///   - onTilkobling: statusbrikken åpner arket med vert, «Koble fra» og «Bytt til demo».
    ///   - onKobleTilPaaNytt: bare når du er koblet til live; gir 401-feilen en vei videre (nytt token).
    init(
        kilde: any NaaKilde, kildeNavn: String, onSvar: ((NaaSkjerm.Handling) -> Void)?,
        onTilkobling: @escaping () -> Void = {}, onKobleTilPaaNytt: (() -> Void)? = nil,
        onKontakt: @escaping (Kontakt) -> Void = { _ in }
    ) {
        _modell = State(initialValue: NaaModell(kilde: kilde))
        self.kildeNavn = kildeNavn
        self.onSvar = onSvar
        self.onTilkobling = onTilkobling
        self.onKobleTilPaaNytt = onKobleTilPaaNytt
        self.onKontakt = onKontakt
    }

    var body: some View {
        let p = Theme.palett(for: scheme)
        ScrollView {
            VStack(spacing: Theme.Avstand.s3) {
                topplinje(p)
                if let feil = modell.feil { feilBrikke(feil) }
                if let skjerm = modell.skjerm {
                    innhold(skjerm)
                } else if modell.feil == nil {
                    HeroView(visning: .laster, tittel: "Henter", undertekst: "Et øyeblikk")
                        .accessibilityIdentifier("naaLaster")
                }
            }
            .padding(.horizontal, Theme.Avstand.s4)
            .padding(.top, Theme.Avstand.s4)
            .padding(.bottom, Theme.Avstand.s4)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await modell.last() }
        #if DEBUG
        // Synsløkken: `--scroll-bunn` åpner nederst, så en lang skjerm kan fotograferes i to biter.
        .defaultScrollAnchor(ProcessInfo.processInfo.arguments.contains("--scroll-bunn") ? .bottom : .top)
        #endif
        .background(Bakgrunn())
        .safeAreaInset(edge: .bottom, spacing: 0) { bunn(p) }
        .task { await modell.last() }
        .onAppear { onKontakt(kontakt) }
        .onChange(of: kontakt) { _, ny in onKontakt(ny) }
        .onChange(of: scenePhase) { _, ny in
            if ny == .active { Task { await modell.last() } }
        }
    }

    // MARK: - deler

    /// Det vi vet om kontakten med trådflata akkurat nå.
    private var kontakt: Kontakt {
        if let f = modell.feil { return .feilet(kreverNyttToken: f.kreverNyttToken, sist: modell.sisteKontakt) }
        if let t = modell.sisteKontakt { return .ok(t) }
        return .ukjent
    }

    /// Plattformstatus når vi har data; ellers tilstanden til selve tilkoblingen (aldri bare et navn).
    private var chip: StatusChip {
        if let f = modell.feil {
            let ord = f.kreverNyttToken ? "Ikke innlogget" : "Får ikke kontakt"
            return StatusChip(lampe: .avvik, tekst: ord, etikett: ord)
        }
        if let s = modell.skjerm {
            return StatusChip(
                lampe: s.plattformOk ? .ok : .avvik,
                tekst: s.plattformOk ? "Plattform ok" : "Plattform avvik",
                etikett: s.plattformOk ? "Plattform ok" : "Plattform har avvik"
            )
        }
        return StatusChip(lampe: .ingen, tekst: "Henter", etikett: "Henter")
    }

    private func topplinje(_ p: Theme.Palette) -> some View {
        HStack {
            Text(modell.skjerm?.topplinje ?? Tid.datolinje(nå: Date(), kalender: .current))
                .skrift(.etikett).foregroundStyle(Color(p.tekst))
                .accessibilityIdentifier("naaDato")
            Spacer()
            // Brikken er også veien til tilkoblingen; uten data (feil, første henting) står den uten lampe.
            Button(action: onTilkobling) { chip }
                .buttonStyle(.plain)
                .accessibilityHint("Åpner tilkoblingen")
                .accessibilityIdentifier("naaTilkoblingKnapp")
        }
        .padding(.horizontal, Theme.Avstand.s1)
        .padding(.bottom, Theme.Avstand.s1)
    }

    @ViewBuilder private func innhold(_ s: NaaSkjerm) -> some View {
        HeroView(
            visning: s.tilstand == .rolig ? .rolig : .krever(s.antallKrever),
            tittel: s.heroTittel, undertekst: s.heroUndertekst
        )
        ForEach(Array(s.godkjenninger.enumerated()), id: \.element.id) { i, g in
            GodkjenningBrikke(godkjenning: g, onSvar: onSvar, idSuffiks: i == 0 ? "" : "-\(i + 1)")
        }
        if !s.venter.isEmpty {
            Listebrikke(tittel: "Venter på deg", rader: s.venter, idPrefiks: "naaVenterListe")
        }
        Brikke(padding: EdgeInsets(top: Theme.Avstand.s4, leading: Theme.Avstand.s5, bottom: Theme.Avstand.s4, trailing: Theme.Avstand.s5)) {
            HStack(alignment: .top, spacing: Theme.Avstand.s4) {
                ForEach(s.kolonner) { k in
                    KolonneTall(kolonne: k).accessibilityIdentifier("naaKolonne-\(k.id)")
                }
            }
        }
        if !s.avvik.isEmpty {
            Listebrikke(tittel: "Avvik", rader: s.avvik, idPrefiks: "naaAvvikListe")
        }
        Listebrikke(
            tittel: "Tråder", hoyre: s.skjulteTraader > 0 ? "+ \(s.skjulteTraader) til" : nil,
            rader: s.traader, tomTekst: "Ingen tråder i gang", idPrefiks: "naaTraaderListe"
        )
        if !s.neste.isEmpty {
            VStack(spacing: Theme.Avstand.s2) {
                ForEach(s.neste) { n in NesteBand(neste: n) }
            }
            .accessibilityIdentifier("naaNeste")
        }
    }

    private func feilBrikke(_ feil: NaaFeil) -> some View {
        let p = Theme.palett(for: scheme)
        return Brikke {
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
                    // Å prøve igjen med et trukket token hjelper ikke. Det lagrede beholdes til nytt er bekreftet.
                    Button(action: onKobleTilPaaNytt) { Text("Koble til på nytt").skrift(.knapp) }
                        .buttonStyle(KnappStil(rolle: .handling))
                        .accessibilityIdentifier("naaKobleTilPaaNytt")
                } else {
                    Button { Task { await modell.last() } } label: {
                        Text("Prøv igjen").skrift(.knapp)
                    }
                    .buttonStyle(KnappStil(rolle: .sekundar))
                    .disabled(modell.henter)
                    .accessibilityIdentifier("naaForsoekIgjen")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("naaFeil")
    }

    /// Tab-bar og fot ligger fast nederst; innholdet blekner under dem.
    private func bunn(_ p: Theme.Palette) -> some View {
        VStack(spacing: Theme.Avstand.s3) {
            Tabbar()
            HStack {
                // «bygg <sha> <klokkeslett>»: hvilken kode som kjører (regel 9). Tiden er byggetidspunktet, ikke nå.
                Text("huginn bygg \(BuildInfo.version)").skrift(.fot).foregroundStyle(Color(p.dempet))
                    .accessibilityIdentifier("versionLabel")
                Spacer()
                Text(kildeNavn).skrift(.fot).foregroundStyle(Color(p.dempet))
                    .accessibilityIdentifier("naaKilde")
            }
            .padding(.horizontal, Theme.Avstand.s1)
        }
        .padding(.horizontal, Theme.Avstand.s4)
        .padding(.top, Theme.Avstand.s3)
        .padding(.bottom, Theme.Avstand.s2)
        .frame(maxWidth: .infinity)
        .background(
            // Heldekkende under tab-baren (de deaktiverte fanene er halvgjennomsiktige og skal ikke vise innhold
            // gjennom seg); en kort overgang over, så innholdet blekner i stedet for å kuttes.
            LinearGradient(
                stops: [.init(color: Color(p.flateBunn).opacity(0), location: 0), .init(color: Color(p.flateBunn), location: 0.14)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}
