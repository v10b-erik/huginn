import SwiftUI
import AppCore

/// «Koble til»: trådflatas adresse og et enhetstoken. Viewet tegner bare; validering, bekreftelse og lagring
/// bor i `Innlogging`/`InnloggingModell`. Tokenet bor i `@State` mens du skriver og ellers bare i Keychain.
struct KoblingView: View {
    var feil: TilkoblingsFeil?
    var kobler: Bool
    var kanAvbryte: Bool
    var onKoble: (_ adresse: String, _ token: String) -> Void
    var onDemo: () -> Void
    var onAvbryt: () -> Void
    var onAvbrytKobling: () -> Void

    @State private var adresse: String
    @State private var token: String
    @FocusState private var fokus: Felt?
    @Environment(\.colorScheme) private var scheme
    private let sendVedStart: Bool
    private let fokusVedStart: Bool

    enum Felt { case adresse, token }

    /// Der tokenet hentes (ikke hemmelig; selve tokenet er det).
    static let tokenSted = "~/.config/devrig/huginn-traadflata-tokens"

    /// - Parameters:
    ///   - forhandsadresse: lagret adresse når det finnes en, ellers standardadressen.
    ///   - forhandstoken/sendVedStart/fokusVedStart: bare synsløkka (DEBUG, falske verdier); ellers tomme/av.
    init(
        feil: TilkoblingsFeil?, kobler: Bool, kanAvbryte: Bool,
        forhandsadresse: String = Tilkobling.standardAdresse, forhandstoken: String = "",
        sendVedStart: Bool = false, fokusVedStart: Bool = false,
        onKoble: @escaping (String, String) -> Void, onDemo: @escaping () -> Void,
        onAvbryt: @escaping () -> Void, onAvbrytKobling: @escaping () -> Void
    ) {
        self.feil = feil
        self.kobler = kobler
        self.kanAvbryte = kanAvbryte
        self.onKoble = onKoble
        self.onDemo = onDemo
        self.onAvbryt = onAvbryt
        self.onAvbrytKobling = onAvbrytKobling
        self.sendVedStart = sendVedStart
        self.fokusVedStart = fokusVedStart
        _adresse = State(initialValue: forhandsadresse)
        _token = State(initialValue: forhandstoken)
    }

    /// Knappen er først aktiv når tokenet er langt nok: valideringen skjer før du trykker, ikke etter.
    private var kanSende: Bool {
        !kobler && !adresse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Tilkobling.tokenLangNok(token)
    }

    var body: some View {
        let p = Theme.palett(for: scheme)
        ScrollView {
            VStack(spacing: Theme.Avstand.s3) {
                // Forklaringen viker mens du skriver: med tastaturet oppe må begge felt og «Koble til» være synlige uten å rulle.
                if fokus == nil { overskrift(p).transition(.opacity) }
                felter(p)
            }
            .padding(.horizontal, Theme.Avstand.s4)
            .padding(.top, Theme.Avstand.s4)
            .padding(.bottom, Theme.Avstand.s4)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(.easeOut(duration: Theme.Varighet.brikke), value: fokus)
        .background(Bakgrunn())
        // `safeAreaInset` følger tastaturet, så knappene ligger alltid over det.
        .safeAreaInset(edge: .bottom, spacing: 0) { bunn(p) }
        .task {
            if sendVedStart { send() }
            if fokusVedStart {
                // Etter et sendt forsøk venter vi til svaret (feilraden) er på plass.
                try? await Task.sleep(for: .milliseconds(sendVedStart ? 2500 : 400))
                fokus = .token
            }
        }
    }

    // MARK: - deler

    private func overskrift(_ p: Theme.Palette) -> some View {
        Brikke(padding: EdgeInsets(top: Theme.Avstand.s5, leading: Theme.Avstand.s5, bottom: Theme.Avstand.s5, trailing: Theme.Avstand.s5)) {
            VStack(alignment: .leading, spacing: Theme.Avstand.s3) {
                Text("Trådflata").skrift(.etikett).foregroundStyle(Color(p.dempet))
                Text("Koble til").skrift(.h2).foregroundStyle(Color(p.tekst))
                    .accessibilityAddTraits(.isHeader)
                Text("Adressen til trådflata og et enhetstoken. Tokenet lagres bare i Keychain på denne enheten.")
                    .skrift(.tekst).foregroundStyle(Color(p.dempet))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Tokenet hentes på ygg-v1: \(Text(verbatim: Self.tokenSted).font(SkriftStil.tid.font))")
                    .skrift(.tekst).foregroundStyle(Color(p.dempet))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("kobling.overskrift")
    }

    private func felter(_ p: Theme.Palette) -> some View {
        Brikke(padding: EdgeInsets(top: Theme.Avstand.s4, leading: Theme.Avstand.s3, bottom: Theme.Avstand.s4, trailing: Theme.Avstand.s3)) {
            VStack(alignment: .leading, spacing: Theme.Avstand.s4) {
                FeltRamme(etikett: "Adresse", laast: kobler) {
                    TextField("", text: $adresse, prompt: Text(verbatim: "https://…").foregroundStyle(Color(p.dempet)))
                        .skrift(.tid)
                        .foregroundStyle(Color(p.tekst))
                        .focused($fokus, equals: .adresse)
                        .submitLabel(.next)
                        .onSubmit { fokus = .token }
                        .urlFeltEgenskaper()
                        .disabled(kobler)
                        .accessibilityLabel("Adresse til trådflata")
                        .accessibilityIdentifier("kobling.adresse")
                }
                if let feil, feil.gjelderAdresse { feilRad(feil, p) }
                FeltRamme(etikett: "Enhetstoken", trailing: tokenTeller, laast: kobler) {
                    SecureField("", text: $token, prompt: Text("Lim inn tokenet").foregroundStyle(Color(p.dempet)))
                        .skrift(.tid)
                        .foregroundStyle(Color(p.tekst))
                        .focused($fokus, equals: .token)
                        .submitLabel(.go)
                        .onSubmit(send)
                        .urlFeltEgenskaper()
                        .disabled(kobler)
                        // Aldri verdien: VoiceOver sier bare hva feltet er.
                        .accessibilityLabel("Enhetstoken")
                        .accessibilityIdentifier("kobling.token")
                }
                // Feilen står rett under feltet den gjelder, så skjemaet over ikke flytter seg når den kommer.
                if let feil, !feil.gjelderAdresse { feilRad(feil, p) }
            }
        }
    }

    /// «N / 24» hele veien (ett format). Når kravet er oppfylt kommer en liten bekreftelse i ord, ikke et nytt tallformat.
    private var tokenTeller: String {
        let n = Tilkobling.tokenLengde(token)
        let teller = "\(n) / \(Tilkobling.minsteTokenLengde)"
        return n >= Tilkobling.minsteTokenLengde ? teller + " · LANG NOK" : teller
    }

    /// Avviksrad: rød lampe + ORD (mono) + forklaringen i Archivo, dempet. Aldri farge alene.
    private func feilRad(_ feil: TilkoblingsFeil, _ p: Theme.Palette) -> some View {
        HStack(alignment: .top, spacing: Theme.Avstand.s3) {
            Circle().fill(Color(p.feil)).frame(width: Theme.Maal.led, height: Theme.Maal.led)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: Theme.Avstand.s1) {
                Text(feil.ord).skrift(.status).foregroundStyle(Color(p.feil))
                Text(feil.melding).skrift(.tekst).foregroundStyle(Color(p.dempet))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Avstand.s1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(feil.tilgjengeligTekst)
        .accessibilityIdentifier("kobling.feil")
    }

    /// Knappene ligger fast nederst (over tastaturet); den ene fylte flaten er «Koble til», og bare når den kan brukes.
    private func bunn(_ p: Theme.Palette) -> some View {
        VStack(spacing: Theme.Avstand.s2) {
            if kobler {
                // Pågår = tone og kant, aldri fylt (regel 2). Rolig: ingen blinking eller spinner.
                Text("Kobler til …").skrift(.knapp).foregroundStyle(Color(p.aksent))
                    .frame(maxWidth: .infinity, minHeight: Theme.Maal.knapp)
                    .glassFlate(radius: Theme.Radius.knapp, variant: .valgt)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Kobler til trådflata")
                    .accessibilityIdentifier("kobling.kobler")
                Button(action: onAvbrytKobling) { Text("Avbryt").skrift(.knapp) }
                    .buttonStyle(KnappStil(rolle: .stille))
                    .accessibilityIdentifier("kobling.avbrytKobler")
            } else {
                Button(action: send) { Text("Koble til").skrift(.knapp) }
                    .buttonStyle(KnappStil(rolle: kanSende ? .handling : .deaktivert))
                    .disabled(!kanSende)
                    .accessibilityIdentifier("kobling.koble")
                HStack(spacing: Theme.Avstand.s2) {
                    Button(action: onDemo) { Text("Prøv demo").skrift(.knapp) }
                        .buttonStyle(KnappStil(rolle: .stille))
                        .accessibilityIdentifier("kobling.demo")
                    if kanAvbryte {
                        Button(action: onAvbryt) { Text("Avbryt").skrift(.knapp) }
                            .buttonStyle(KnappStil(rolle: .stille))
                            .accessibilityIdentifier("kobling.avbryt")
                    }
                }
            }
            // Regel 9: hvilken kode som kjører. Venstrestilt, som i «Nå».
            HStack {
                Text("huginn bygg \(BuildInfo.version)").skrift(.fot).foregroundStyle(Color(p.dempet))
                    .accessibilityIdentifier("versionLabel")
                Spacer()
            }
            .padding(.horizontal, Theme.Avstand.s1)
            .padding(.top, Theme.Avstand.s1)
        }
        .padding(.horizontal, Theme.Avstand.s4)
        .padding(.top, Theme.Avstand.s3)
        .padding(.bottom, Theme.Avstand.s2)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                stops: [.init(color: Color(p.flateBunn).opacity(0), location: 0), .init(color: Color(p.flateBunn), location: 0.14)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    private func send() {
        guard kanSende else { return }
        fokus = nil
        onKoble(adresse, token)
    }
}

/// Et skrivefelt i et innfelt bånd (som `Band`), med sperret etikett over (flukter med båndets kant).
private struct FeltRamme<Innhold: View>: View {
    var etikett: String
    var trailing: String? = nil
    /// Låst (mens det kobles): VERDIEN dempes, ikke etiketten (som må holde kontrast).
    var laast = false
    @ViewBuilder var innhold: Innhold
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        VStack(alignment: .leading, spacing: Theme.Avstand.s2) {
            HStack {
                Text(etikett).skrift(.etikett).foregroundStyle(Color(p.dempet))
                Spacer()
                if let trailing { Text(trailing).skrift(.tid).monospacedDigit().foregroundStyle(Color(p.dempet)) }
            }
            .accessibilityHidden(true)
            innhold
                .opacity(laast ? 0.55 : 1)
                .padding(.horizontal, Theme.Avstand.s3)
                .frame(minHeight: Theme.Maal.beroringMin + Theme.Avstand.s2)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.band, style: .continuous).fill(Color(p.band)))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.band, style: .continuous).strokeBorder(Color(p.kant), lineWidth: 1))
        }
    }
}

extension View {
    /// Adresse og token er ikke prosa: ingen autokorrektur, ingen store bokstaver. iOS-only API samlet her, én gang.
    func urlFeltEgenskaper() -> some View {
        self.autocorrectionDisabled(true)
        #if os(iOS)
            .textInputAutocapitalization(.never)
        #endif
    }
}
