import SwiftUI
import AppCore

/// «Nå»: det som venter på deg, og ingenting annet. Viewet tegner bare `NaaSkjerm`; ingen logikk bor her.
struct NaaView: View {
    @State private var modell: NaaModell
    /// Hvilken kilde dette er. DEBUG-argumentene for auto-svar virker bare når den er en demo.
    private let valg: KildeValg
    private let kildeNavn: String
    private let smaltKildeNavn: String
    private let onTilkobling: () -> Void
    private let onKobleTilPaaNytt: (() -> Void)?
    private let onKontakt: (Kontakt) -> Void
    private let onVelgFane: (Hovedfane) -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    /// Bekreftelsen som vises. Egen tilstand (ikke utledet) så arket beholder innholdet mens det lukkes.
    @State private var ark: ArkData?

    /// - Parameters:
    ///   - tilgang: kilden og skriveveien (Godkjenn/Avslå) bygget sammen, så de deler tilstand (demo: hva som er avgjort).
    ///   - autentisering: lokal autentisering før Godkjenn. `nil` = ingen skrivevei, og knappene er deaktiverte.
    ///   - onTilkobling: statusbrikken åpner arket med vert, «Koble fra» og «Bytt til demo».
    ///   - onKobleTilPaaNytt: bare når du er koblet til live; gir 401-feilen en vei videre (nytt token).
    init(
        tilgang: KildeValg.Tilgang, autentisering: (any Autentisering)?, valg: KildeValg, kildeNavn: String, smaltKildeNavn: String? = nil,
        onTilkobling: @escaping () -> Void = {}, onKobleTilPaaNytt: (() -> Void)? = nil,
        onKontakt: @escaping (Kontakt) -> Void = { _ in }, onVelgFane: @escaping (Hovedfane) -> Void = { _ in }
    ) {
        _modell = State(initialValue: NaaModell(
            kilde: tilgang.kilde, send: autentisering == nil ? nil : tilgang.send, autentisering: autentisering
        ))
        self.valg = valg
        self.kildeNavn = kildeNavn
        self.smaltKildeNavn = smaltKildeNavn ?? kildeNavn
        self.onTilkobling = onTilkobling
        self.onKobleTilPaaNytt = onKobleTilPaaNytt
        self.onKontakt = onKontakt
        self.onVelgFane = onVelgFane
    }

    /// Innholdets maksbredde. Synsløkka (`--bredde=375`, bare DEBUG) etterligner en smal skjerm uten en smal simulator.
    private static var maksBredde: CGFloat {
        #if DEBUG
        if let v = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--bredde=") }),
           let b = Double(v.dropFirst("--bredde=".count)) { return b }
        #endif
        return 560
    }

    var body: some View {
        let p = Theme.palett(for: scheme)
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: Theme.Avstand.s3) {
                topplinje(p)
                if let feil = modell.feil { feilBrikke(feil) }
                if let skjerm = modell.synligSkjerm {
                    innhold(skjerm)
                } else if modell.feil == nil {
                    HeroView(visning: .laster, tittel: "Henter", undertekst: "Et øyeblikk")
                        .accessibilityIdentifier("naaLaster")
                }
            }
            .padding(.horizontal, Theme.Avstand.s4)
            .padding(.top, Theme.Avstand.s4)
            .padding(.bottom, Theme.Avstand.s4)
            .frame(maxWidth: Self.maksBredde)
            .frame(maxWidth: .infinity)
        }
        #if DEBUG
        // Synsløkken: `--scroll-venter` / `--scroll-traader` åpner med den brikken øverst (lange skjermer kan ikke
        // vises i ett bilde).
        .task {
            let args = ProcessInfo.processInfo.arguments
            guard let mal = args.contains("--scroll-venter") ? "naaVenter" : (args.contains("--scroll-traader") ? "naaTraader" : nil) else { return }
            try? await Task.sleep(for: .milliseconds(600))
            proxy.scrollTo(mal, anchor: .top)
        }
        #endif
        }
        .refreshable { await modell.last() }
        .sheet(item: Binding(get: { ark }, set: { if $0 == nil { modell.lukkSvar() } })) { data in
            BekreftelseArk(
                forespørsel: data.forespørsel, autentiserer: data.autentiserer,
                onBekreft: { modell.bekreftSvar() }, onAvbryt: { modell.lukkSvar() }
            )
            .interactiveDismissDisabled(data.autentiserer)
        }
        .onChange(of: arkData, initial: true) { _, ny in ark = ny }
        // Kvitteringen er en stille bekreftelse som står til neste interaksjon (nytt valg), eller i 30 sekunder.
        .task(id: modell.svar?.kvittering?.tid) {
            guard modell.svar?.kvittering != nil else { return }
            try? await Task.sleep(for: .seconds(30))
            if !Task.isCancelled { modell.svar?.lukkKvittering() }
        }
        #if DEBUG
        // Synsløkken: `--auto-svar=godkjenn|avslaa` åpner bekreftelsen for første kort, `--auto-bekreft` trykker bekreft.
        .task {
            let args = ProcessInfo.processInfo.arguments
            // Bare demo: mot en live kilde gir autoSvar alltid nil.
            guard let svarValg = KildeValg.autoSvar(argumenter: args, tillatLive: true, valg: valg) else { return }
            for _ in 0..<100 where modell.skjerm == nil { try? await Task.sleep(for: .milliseconds(50)) }
            guard let g = modell.skjerm?.godkjenninger.first else { return }
            guard let handling = svarValg == .godkjenn ? g.godkjenn : g.avslaa else { return }
            modell.velg(handling)
            if KildeValg.brukerAutoBekreft(argumenter: args, tillatLive: true, valg: valg) {
                try? await Task.sleep(for: .milliseconds(1500))
                modell.bekreftSvar()
            }
        }
        #endif
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
        let heroVisning: HeroView.Visning = switch s.tilstand {
        case .krever(let n): .krever(n)
        case .ingenOppgaver: .ingenOppgaver
        case .rolig: .rolig
        }
        HeroView(visning: heroVisning, tittel: s.heroTittel, undertekst: s.heroUndertekst, tale: s.heroTale)
        svarRad
        ForEach(Array(s.godkjenninger.enumerated()), id: \.element.id) { i, g in
            GodkjenningBrikke(
                godkjenning: g, onSvar: modell.svar == nil ? nil : { modell.velg($0) },
                knapper: knapper(for: g), onOppdater: { Task { await modell.oppdaterEtterSvar() } }, idSuffiks: i == 0 ? "" : "-\(i + 1)"
            )
        }
        if !s.venter.isEmpty {
            Listebrikke(tittel: "Venter på deg", rader: s.venter, idPrefiks: "naaVenterListe")
                #if DEBUG
                .padding(.top, ProcessInfo.processInfo.arguments.contains("--scroll-venter") ? 56 : 0)  // under statuslinja i bildet
                #endif
                .id("naaVenter")
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
        #if DEBUG
        .padding(.top, ProcessInfo.processInfo.arguments.contains("--scroll-traader") ? 56 : 0)  // under statuslinja i bildet
        #endif
        .id("naaTraader")
        if !s.neste.isEmpty {
            VStack(spacing: Theme.Avstand.s2) {
                ForEach(s.neste) { n in NesteBand(neste: n) }
            }
            .accessibilityIdentifier("naaNeste")
        }
    }

    // MARK: Godkjenn/Avslå

    /// Hva knappene på et kort gjør nå: av mens noe annet pågår eller en usikkerhet ikke er kvittert; «Sender …» på kortet
    /// som sendes. Én forsendelse om gangen, for alle kortene.
    private func knapper(for g: NaaSkjerm.Godkjenning) -> GodkjenningBrikke.Knapper {
        switch modell.svar?.svar.knapper(for: g.id) ?? .av {
        case .aktive: .aktive
        case .av: .av
        case .sender(let f):
            .sender(f.valg.erAvslag ? "Sender avslag …"
                : (f.valg.key == "approve" ? "Sender godkjenning …" : "Sender «\(f.valg.etikett)» …"))
        case .usikker(let f): .usikker(Svar.usikkerVisning(for: f))
        }
    }

    /// Raden over kortene: feil/usikkerhet som avviksrad, eller en stille kvittering.
    @ViewBuilder private var svarRad: some View {
        if let k = modell.svar?.kvittering {
            let f = k.forespørsel
            SvarRad(
                innhold: .kvittering(
                    ord: "\(f.valg.erAvslag ? "Avslått" : "Godkjent") \(Tid.hhmm(k.tid, kalender: .current))",
                    tekst: f.valg.key == "approve" || f.valg.erAvslag ? f.forsteLinje : "\(f.forsteLinje) · \(f.valg.etikett)"
                ),
                onOppdater: {}, onLukk: { modell.svar?.lukkKvittering() }
            )
        }
        switch modell.svar?.tilstand {
        case .usikker(let f)?:
            // Mens kortet står der, bor usikkerheten INNE i kortet. Er kortet allerede borte, står den her.
            if modell.synligSkjerm?.godkjenninger.contains(where: { $0.id == f.kortId }) != true {
                SvarRad(
                    innhold: .avvik(Svar.usikkerBorteVisning(for: f), oppdater: true, kreverNyttToken: false),
                    onOppdater: { Task { await modell.oppdaterEtterSvar() } }, onLukk: { modell.lukkSvar() }
                )
            }
        case .feil(let f)?:
            let oppdater: Bool = switch f {
            case .alleredeAvgjort, .ukjentKort: true
            default: false
            }
            SvarRad(
                innhold: .avvik(f.visning, oppdater: oppdater, kreverNyttToken: f.kreverNyttToken),
                onOppdater: { Task { await modell.oppdaterEtterSvar() } }, onLukk: { modell.lukkSvar() },
                onKobleTilPaaNytt: onKobleTilPaaNytt
            )
        default:
            EmptyView()
        }
    }

    /// Det bekreftelsen viser nå. `nil` utenfor `.bekrefter`/`.autentiserer`.
    private var arkData: ArkData? {
        switch modell.svar?.tilstand {
        case .bekrefter(let f)?: ArkData(forespørsel: f, autentiserer: false)
        case .autentiserer(let forsøk)?: ArkData(forespørsel: forsøk.forespørsel, autentiserer: true)
        default: nil
        }
    }

    struct ArkData: Identifiable, Equatable {
        var forespørsel: Svar.Forespørsel
        var autentiserer: Bool
        var id: String { forespørsel.kortId }
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

    /// Tab-bar og fot ligger fast nederst (`BunnView`, delt med «Tråder»); innholdet blekner under dem.
    private func bunn(_ p: Theme.Palette) -> some View {
        BunnView(valgt: .naa, onVelg: onVelgFane, kildeNavn: kildeNavn, smaltKildeNavn: smaltKildeNavn)
    }
}
