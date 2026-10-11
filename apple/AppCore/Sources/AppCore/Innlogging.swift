import Foundation

/// Hvor i innloggingen appen står. Ren tilstandsmaskin: ingen UI og ingen nettverk (kalleren bekrefter med
/// `bekreftTilkobling` og melder utfallet tilbake). Den eneste bivirkningen er lageret, og lageret skrives
/// bare i `kobletOk`, altså etter at tilkoblingen er bekreftet. Et mislykket forsøk rører aldri det som er lagret.
public struct Innlogging {
    public enum Tilstand: Equatable, Sendable {
        case laster
        case ikkeKoblet(feil: TilkoblingsFeil?)
        case kobler
        case koblet(Tilkobling)
        case demo(rolig: Bool)
    }

    public private(set) var tilstand: Tilstand = .laster
    /// Det som ligger i lageret (så vidt vi vet), uavhengig av hva som vises nå.
    public private(set) var lagret: Tilkobling?
    /// Feil fra en handling som ikke endrer tilstanden (f.eks. at `slett` feilet mens du fortsatt er koblet til).
    public private(set) var handlingsFeil: TilkoblingsFeil?

    private let lager: any TilkoblingLager
    private let tillatHttpLoopback: Bool
    /// Der vi var før «Koble til» ble åpnet, så «Avbryt» kan gå tilbake uten å ha rørt noe.
    private var forrige: Tilstand?

    /// - Parameter tillatHttpLoopback: `true` bare i DEBUG-bygg.
    public init(lager: any TilkoblingLager, tillatHttpLoopback: Bool = false) {
        self.lager = lager
        self.tillatHttpLoopback = tillatHttpLoopback
    }

    public var kanAvbryte: Bool {
        if case .ikkeKoblet = tilstand, forrige != nil { return true }
        return false
    }

    // MARK: - handlinger

    /// Velger første tilstand: launch-argument, så DEBUG-miljø, så det som er lagret, ellers `.ikkeKoblet`.
    public mutating func start(argumenter: [String], miljo: [String: String], tillatLive: Bool) {
        handlingsFeil = nil
        forrige = nil
        var leseFeil = false
        do { lagret = try lager.les() } catch { lagret = nil; leseFeil = true }
        let valg = KildeValg.velg(argumenter: argumenter, miljo: miljo, tillatLive: tillatLive, lagret: lagret)
        switch valg {
        case .demo(let rolig): tilstand = .demo(rolig: rolig)
        case .live(let url, let token): tilstand = .koblet(Tilkobling(baseURL: url, token: token))
        case nil: tilstand = .ikkeKoblet(feil: leseFeil ? .kunneIkkeLese : nil)
        }
    }

    /// Validerer og går til `.kobler`; gir tilkoblingen som skal bekreftes. Ved ugyldig inndata blir tilstanden
    /// `.ikkeKoblet(feil:)` og svaret `nil`. Ingenting skrives.
    @discardableResult
    public mutating func koble(adresse: String, token: String) -> Tilkobling? {
        guard case .ikkeKoblet = tilstand else { return nil }
        handlingsFeil = nil
        do {
            let t = try Tilkobling.fra(adresse: adresse, token: token, tillatHttpLoopback: tillatHttpLoopback)
            tilstand = .kobler
            return t
        } catch {
            tilstand = .ikkeKoblet(feil: error)
            return nil
        }
    }

    /// Bekreftet av serveren: først nå skrives Keychain. Feiler skrivingen, er det ikke noe tilkoblet, og
    /// det som lå der fra før er uendret (oppdater-eller-legg-til er atomisk per element).
    public mutating func kobletOk(_ t: Tilkobling) {
        guard case .kobler = tilstand else { return }
        do {
            try lager.lagre(t)
            lagret = t
            forrige = nil
            tilstand = .koblet(t)
        } catch {
            tilstand = .ikkeKoblet(feil: .kunneIkkeLagre)
        }
    }

    /// Brukeren avbrøt «Kobler til»: tilbake til skjemaet uten feil (avbrudd er ikke en feil) og uten å røre lageret.
    public mutating func avbrytKobler() {
        guard case .kobler = tilstand else { return }
        tilstand = .ikkeKoblet(feil: nil)
    }

    /// Bekreftelsen feilet: tilbake til skjemaet med årsaken. Lageret røres ikke.
    public mutating func kobletFeilet(_ feil: TilkoblingsFeil) {
        guard case .kobler = tilstand else { return }
        tilstand = .ikkeKoblet(feil: feil)
    }

    /// Sletter fra lageret. Feiler slettingen, er vi fortsatt koblet til (og sier fra), i stedet for å late som.
    public mutating func kobleFra() {
        guard case .koblet = tilstand else { return }
        do {
            try lager.slett()
            lagret = nil
            handlingsFeil = nil
            forrige = nil
            tilstand = .ikkeKoblet(feil: nil)
        } catch {
            handlingsFeil = .kunneIkkeSlette
        }
    }

    /// Demo for denne økten; lageret røres ikke (neste oppstart går til det lagrede igjen).
    public mutating func prøvDemo(rolig: Bool = false) {
        switch tilstand {
        case .ikkeKoblet, .koblet, .demo:
            handlingsFeil = nil
            forrige = nil
            tilstand = .demo(rolig: rolig)
        case .laster, .kobler: break
        }
    }

    /// Åpner «Koble til» fra «Nå» (f.eks. «Koble til på nytt» etter 401, eller fra demo). Det lagrede beholdes
    /// til en ny tilkobling er bekreftet.
    public mutating func visKobling() {
        switch tilstand {
        case .koblet, .demo:
            handlingsFeil = nil
            forrige = tilstand
            tilstand = .ikkeKoblet(feil: nil)
        case .laster, .ikkeKoblet, .kobler: break
        }
    }

    /// Tilbake dit vi var før `visKobling`.
    public mutating func avbryt() {
        guard case .ikkeKoblet = tilstand, let f = forrige else { return }
        forrige = nil
        tilstand = f
    }

    /// Fra demo tilbake til det lagrede, når noe er lagret.
    public mutating func brukLagret() {
        guard case .demo = tilstand, let t = lagret else { return }
        forrige = nil
        tilstand = .koblet(t)
    }
}
