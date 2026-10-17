import SwiftUI
import AppCore

/// «Tråder»: lesevisning over trådene trådflata kjenner. Viewet tegner bare `TraadSkjerm`; ingen logikk bor her.
/// Fem tilstander (liste, tom, henter, feil, utlogget), og ALLE tegner samme listekort (radius `brikke`, samme overskrift),
/// så ingenting hopper når data kommer. Ingen skriving, ingen handlinger i denne runden.
struct TraaderView: View {
    @State private var modell: TraaderModell
    private let kildeNavn: String
    private let smaltKildeNavn: String
    private let onTilkobling: () -> Void
    private let onVelgFane: (Hovedfane) -> Void
    /// Fanen er den valgte. Skjermen bor videre (skjult) når du bytter fane; ved retur hentes den på nytt hvis den er gammel.
    private let erSynlig: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize

    /// - Parameter onTilkobling: åpner tilkoblingsarket (samme vei som statusbrikken på «Nå»); «Koble til» ved utlogging.
    init(
        kilde: any TraadKilde, kildeNavn: String, smaltKildeNavn: String? = nil, erSynlig: Bool = true,
        onTilkobling: @escaping () -> Void = {}, onVelgFane: @escaping (Hovedfane) -> Void
    ) {
        _modell = State(initialValue: TraaderModell(kilde: kilde))
        self.kildeNavn = kildeNavn
        self.smaltKildeNavn = smaltKildeNavn ?? kildeNavn
        self.erSynlig = erSynlig
        self.onTilkobling = onTilkobling
        self.onVelgFane = onVelgFane
    }

    /// Innholdets maksbredde. Synsløkka (`--bredde=375`, bare DEBUG) etterligner en smal skjerm, som på «Nå».
    private static var maksBredde: CGFloat {
        #if DEBUG
        if let v = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--bredde=") }),
           let b = Double(v.dropFirst("--bredde=".count)) { return b }
        #endif
        return 560
    }

    var body: some View {
        let p = Theme.palett(for: scheme)
        ScrollView {
            VStack(spacing: Theme.Avstand.s3) {
                topplinje(p)
                if let feil = modell.feil { FeilBand(feil: feil, onKobleTil: onTilkobling, onProv: { Task { await modell.last() } }, henter: modell.henter) }
                innhold(p)
            }
            .padding(.horizontal, Theme.Avstand.s4)
            .padding(.top, Theme.Avstand.s4)
            .padding(.bottom, Theme.Avstand.s5)
            .frame(maxWidth: Self.maksBredde)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await modell.last() }
        #if DEBUG
        // Synsløkka: `--scroll-bunn` åpner nederst, så siste rad kan fotograferes mot fanelinja.
        .defaultScrollAnchor(ProcessInfo.processInfo.arguments.contains("--scroll-bunn") ? .bottom : .top)
        #endif
        .background(Bakgrunn())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BunnView(valgt: .traader, onVelg: onVelgFane, kildeNavn: kildeNavn, smaltKildeNavn: smaltKildeNavn)
        }
        .task { await modell.last() }
        .onChange(of: erSynlig) { _, synlig in
            if synlig { Task { await modell.lastHvisGammel() } }
        }
        .onChange(of: scenePhase) { _, ny in
            if ny == .active { Task { await modell.last() } }
        }
    }

    // MARK: - topp

    /// Som på «Nå»: mono-etikett til venstre, statusboks til høyre. Fra AX-størrelsene står boksen under etiketten.
    @ViewBuilder private func topplinje(_ p: Theme.Palette) -> some View {
        let etikett = Text(TraadSkjerm.toppEtikett).skrift(.etikett).foregroundStyle(Color(p.tekst))
            .accessibilityIdentifier("traaderTittel")
            .accessibilityAddTraits(.isHeader)
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Avstand.s2) { etikett; chip }
            } else {
                HStack(spacing: Theme.Avstand.s3) {
                    etikett.lineLimit(1)
                    Spacer(minLength: Theme.Avstand.s3)
                    chip
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Avstand.s1)
        .padding(.bottom, Theme.Avstand.s1)
    }

    /// «N VENTER» (fylt aksentlampe: krever deg) / «ALT ROLIG» (grønn lampe) når vi har en liste; ellers tilstanden til
    /// selve hentingen. Boksen er et ORD (regel 4), og den er stille: ingen handling bak den.
    private var chip: StatusChip {
        let id = "traaderStatusChip"
        if let f = modell.feil {
            return f.kreverNyttToken
                ? StatusChip(lampe: .ingen, tekst: "Utlogget", etikett: "Utlogget", aksentLampe: true, id: id)
                : StatusChip(lampe: .avvik, tekst: "Feilet", etikett: "Feilet", id: id)
        }
        guard let s = modell.skjerm else { return StatusChip(lampe: .ingen, tekst: "Henter", etikett: "Henter", id: id) }
        return s.venter.isEmpty
            ? StatusChip(lampe: .ok, tekst: s.statusTekst, etikett: "Alt rolig", id: id)
            : StatusChip(lampe: .ingen, tekst: s.statusTekst, etikett: "\(s.venter.count) tråder venter på deg", aksentLampe: true, id: id)
    }

    // MARK: - innhold

    @ViewBuilder private func innhold(_ p: Theme.Palette) -> some View {
        if let s = modell.skjerm {
            // Også ved feil/ny henting: forrige liste blir stående, med feilbåndet over.
            if s.rader.isEmpty {
                Listebrikke(tittel: "Siste aktivitet", hoyre: s.antallTekst, rader: [], tomTekst: s.tomTekst, idPrefiks: "traaderListe")
            } else {
                Listebrikke(
                    tittel: "Siste aktivitet", hoyre: s.antallTekst, rader: s.rader,
                    grupper: s.venter.isEmpty ? nil : [
                        .init(etikett: "Venter på deg", rader: s.venter),
                        .init(etikett: "Øvrige", rader: s.ovrige),
                    ],
                    idPrefiks: "traaderListe"
                )
                if s.kanVæreAvkortet {
                    Text("Viser de \(TraadSkjerm.serverGrense) nyeste")
                        .skrift(.undertekst).foregroundStyle(Color(p.dempet))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.Avstand.s1)
                        .accessibilityIdentifier("traaderAvkortet")
                }
            }
        } else if let f = modell.feil {
            // Ingen liste å vise: samme kort, uten tall (et 0 ville påstått at det ikke finnes tråder).
            Listebrikke(
                tittel: "Siste aktivitet", hoyre: "– · \(TraadSkjerm.vinduDager) D", rader: [],
                tomTekst: f.kreverNyttToken ? "Koble til for å se trådene" : "Trådene kunne ikke hentes",
                idPrefiks: "traaderListe"
            )
        } else {
            Listebrikke(tittel: "Siste aktivitet", hoyre: "– · \(TraadSkjerm.vinduDager) D", rader: [], skjelett: true, idPrefiks: "traaderListe")
                .accessibilityIdentifier("traaderLaster")
        }
    }
}

/// Feilbåndet (radius `band`): lampe, tittel og tilstandsord på radenes innrykk, brødtekst i Archivo (regel 5: mono er
/// for tekniske ting), og knappen som er den ene veien videre. Én glassflate; knappen inni har ingen egen skygge.
///
/// Utlogget (401) er ikke et avvik i data: ordet er UTLOGGET, lampen aksent (du må handle), og veien videre er «Koble til»
/// (tilkoblingsarket), ikke «Prøv igjen» (som ikke hjelper med et trukket token). Nettverksfeil: FEILET, rød lampe, «Prøv igjen».
private struct FeilBand: View {
    var feil: NaaFeil
    var onKobleTil: () -> Void
    var onProv: () -> Void
    var henter: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let p = Theme.palett(for: scheme)
        let utlogget = feil.kreverNyttToken
        let lampe = Circle().fill(utlogget ? Color(p.aksent) : Color(p.feil))
            .frame(width: Theme.Maal.led, height: Theme.Maal.led).frame(width: 14, alignment: .leading)
        let ord = Text(utlogget ? "UTLOGGET" : "FEILET").skrift(.status)
            .foregroundStyle(utlogget ? Color(p.aksent) : Color(p.feil))
            .lineLimit(1).fixedSize(horizontal: true, vertical: false)
        let tekst = VStack(alignment: .leading, spacing: 1) {
            Text(feil.tittel).skrift(.tekst).foregroundStyle(Color(p.tekst))
            Text(feil.detalj).skrift(.tekst).foregroundStyle(Color(p.dempet))
        }
        VStack(alignment: .leading, spacing: Theme.Avstand.s3) {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Avstand.s2) {
                    HStack(spacing: Theme.Avstand.s3) { lampe; ord }
                    tekst
                }
            } else {
                HStack(alignment: .center, spacing: Theme.Avstand.s3) {
                    lampe
                    tekst
                    Spacer(minLength: Theme.Avstand.s2)
                    ord
                }
            }
            if utlogget {
                Button(action: onKobleTil) { Text("Koble til").skrift(.knapp) }
                    .buttonStyle(KnappStil(rolle: .handling))
                    .accessibilityIdentifier("traaderKobleTil")
            } else {
                Button(action: onProv) { Text("Prøv igjen").skrift(.knapp) }
                    .buttonStyle(KnappStil(rolle: .omriss))
                    .disabled(henter)
                    .accessibilityIdentifier("traaderForsoekIgjen")
            }
        }
        .padding(EdgeInsets(top: Theme.Avstand.s4, leading: Theme.Avstand.s5, bottom: Theme.Avstand.s4, trailing: Theme.Avstand.s5))
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassFlate(radius: Theme.Radius.band)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("traaderFeil")
    }
}
