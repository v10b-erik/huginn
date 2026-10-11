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

    @State private var adresse: String
    @State private var token: String
    @FocusState private var fokus: Felt?
    @Environment(\.colorScheme) private var scheme
    private let sendVedStart: Bool

    enum Felt { case adresse, token }

    /// - Parameters:
    ///   - forhandsadresse/forhandstoken/sendVedStart: bare synsløkka (DEBUG, falske verdier); ellers tomme.
    init(
        feil: TilkoblingsFeil?, kobler: Bool, kanAvbryte: Bool,
        forhandsadresse: String = Tilkobling.standardAdresse, forhandstoken: String = "", sendVedStart: Bool = false,
        onKoble: @escaping (String, String) -> Void, onDemo: @escaping () -> Void, onAvbryt: @escaping () -> Void
    ) {
        self.feil = feil
        self.kobler = kobler
        self.kanAvbryte = kanAvbryte
        self.onKoble = onKoble
        self.onDemo = onDemo
        self.onAvbryt = onAvbryt
        self.sendVedStart = sendVedStart
        _adresse = State(initialValue: forhandsadresse)
        _token = State(initialValue: forhandstoken)
    }

    private var kanSende: Bool {
        !kobler && !adresse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let p = Theme.palett(for: scheme)
        ScrollView {
            VStack(spacing: Theme.Avstand.s3) {
                overskrift(p)
                if let feil { feilRad(feil, p) }
                felter(p)
            }
            .padding(.horizontal, Theme.Avstand.s4)
            .padding(.top, Theme.Avstand.s4)
            .padding(.bottom, Theme.Avstand.s4)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Bakgrunn())
        // `safeAreaInset` følger tastaturet, så knappene ligger alltid over det.
        .safeAreaInset(edge: .bottom, spacing: 0) { bunn(p) }
        .task {
            if sendVedStart { send() }
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
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("kobling.overskrift")
    }

    private func felter(_ p: Theme.Palette) -> some View {
        Brikke(padding: EdgeInsets(top: Theme.Avstand.s4, leading: Theme.Avstand.s3, bottom: Theme.Avstand.s4, trailing: Theme.Avstand.s3)) {
            VStack(alignment: .leading, spacing: Theme.Avstand.s4) {
                FeltRamme(etikett: "Adresse") {
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
                FeltRamme(etikett: "Enhetstoken") {
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
            }
        }
    }

    /// Avviksrad: rød lampe + ORD + meldingen. Aldri farge alene.
    private func feilRad(_ feil: TilkoblingsFeil, _ p: Theme.Palette) -> some View {
        Brikke(padding: EdgeInsets(top: Theme.Avstand.s4, leading: Theme.Avstand.s4, bottom: Theme.Avstand.s4, trailing: Theme.Avstand.s4)) {
            HStack(alignment: .top, spacing: Theme.Avstand.s3) {
                Circle().fill(Color(p.feil)).frame(width: Theme.Maal.led, height: Theme.Maal.led)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: Theme.Avstand.s1) {
                    Text(feil.ord).skrift(.status).foregroundStyle(Color(p.feil))
                    Text(feil.melding).skrift(.undertekst).foregroundStyle(Color(p.tekst))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(feil.tilgjengeligTekst)
        .accessibilityIdentifier("kobling.feil")
    }

    /// Knappene ligger fast nederst (over tastaturet); den ene fylte flaten er «Koble til».
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
            } else {
                // Fylt flate = handlingen er tilgjengelig. Før feltene er fylt står den som glass med dempet
                // tekst (en blek fylt flate med hvit tekst er uleselig i lys modus).
                Button(action: send) { Text("Koble til").skrift(.knapp) }
                    .buttonStyle(KnappStil(rolle: kanSende ? .handling : .sekundar))
                    .disabled(!kanSende)
                    .opacity(kanSende ? 1 : 0.6)
                    .accessibilityIdentifier("kobling.koble")
            }
            HStack(spacing: Theme.Avstand.s2) {
                Button(action: onDemo) { Text("Prøv demo").skrift(.knapp) }
                    .buttonStyle(KnappStil(rolle: .stille))
                    .disabled(kobler)
                    .accessibilityIdentifier("kobling.demo")
                if kanAvbryte {
                    Button(action: onAvbryt) { Text("Avbryt").skrift(.knapp) }
                        .buttonStyle(KnappStil(rolle: .stille))
                        .disabled(kobler)
                        .accessibilityIdentifier("kobling.avbryt")
                }
            }
            // Regel 9: hvilken kode som kjører.
            Text("huginn bygg \(BuildInfo.version)").skrift(.fot).foregroundStyle(Color(p.dempet))
                .accessibilityIdentifier("versionLabel")
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

/// Et skrivefelt i et innfelt bånd (som `Band`), med sperret etikett over.
private struct FeltRamme<Innhold: View>: View {
    var etikett: String
    @ViewBuilder var innhold: Innhold
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        VStack(alignment: .leading, spacing: Theme.Avstand.s2) {
            Text(etikett).skrift(.etikett).foregroundStyle(Color(p.dempet))
                .padding(.horizontal, Theme.Avstand.s1)
                .accessibilityHidden(true)
            innhold
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
