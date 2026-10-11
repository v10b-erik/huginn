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
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
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
        onKontakt: @escaping (Kontakt) -> Void = { _ in }
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
            .frame(maxWidth: 560)
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
            .presentationDetents([.large])
            .interactiveDismissDisabled(data.autentiserer)
        }
        .onChange(of: arkData, initial: true) { _, ny in ark = ny }
        // Kvitteringen er en stille bekreftelse som står til neste interaksjon (nytt valg), eller i 30 sekunder.
        .task(id: ferdigKortId) {
            guard ferdigKortId != nil else { return }
            try? await Task.sleep(for: .seconds(30))
            if !Task.isCancelled, ferdigKortId != nil { modell.lukkSvar() }
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
        HeroView(
            visning: s.tilstand == .rolig ? .rolig : .krever(s.antallKrever),
            tittel: s.heroTittel, undertekst: s.heroUndertekst
        )
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
        switch modell.svar?.tilstand {
        case .sender(let f)? where f.forespørsel.kortId == g.id:
            .sender(f.forespørsel.valg.erAvslag ? "Sender avslag …"
                : (f.forespørsel.valg.key == "approve" ? "Sender godkjenning …" : "Sender «\(f.forespørsel.valg.label)» …"))
        case .usikker(let f)? where f.kortId == g.id: .usikker(Svar.usikkerVisning(for: f))
        case .sender?, .autentiserer?, .usikker?, .ferdig?: .av
        default: .aktive
        }
    }

    /// Raden over kortene: feil/usikkerhet som avviksrad, eller en stille kvittering.
    @ViewBuilder private var svarRad: some View {
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
        case .ferdig(let f)?:
            let kl = Tid.hhmm(modell.svar?.sistFerdig ?? Date(), kalender: .current)
            SvarRad(
                innhold: .kvittering(
                    ord: "\(f.valg.erAvslag ? "Avslått" : "Godkjent") \(kl)",
                    tekst: f.valg.key == "approve" || f.valg.erAvslag ? f.forsteLinje : "\(f.forsteLinje) · \(f.valg.label)"
                ),
                onOppdater: {}, onLukk: { modell.lukkSvar() }
            )
        default:
            EmptyView()
        }
    }

    private var ferdigKortId: String? {
        if case .ferdig(let f)? = modell.svar?.tilstand { return f.kortId }
        return nil
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

    // MARK: fot

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

    /// Tab-bar og fot ligger fast nederst; innholdet blekner under dem.
    private func bunn(_ p: Theme.Palette) -> some View {
        VStack(spacing: Theme.Avstand.s3) {
            Tabbar()
            fot(p)
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
