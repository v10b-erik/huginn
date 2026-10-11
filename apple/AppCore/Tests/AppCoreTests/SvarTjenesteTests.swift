import Foundation
import Testing
@testable import AppCore

/// Fake `Autentisering`: teller kall, husker begrunnelsene, og kan holdes åpen til testen slipper den.
final class FakeAutentisering: Autentisering, @unchecked Sendable {
    private let lås = NSLock()
    private var _utfall: AutentiseringsUtfall
    private var _begrunnelser: [String] = []
    private var ventende: CheckedContinuation<Void, Never>?
    private var holdes: Bool

    init(_ utfall: AutentiseringsUtfall = .ok, holdes: Bool = false) {
        _utfall = utfall
        self.holdes = holdes
    }

    var begrunnelser: [String] { lås.withLock { _begrunnelser } }
    var antall: Int { begrunnelser.count }

    func autentiser(begrunnelse: String) async -> AutentiseringsUtfall {
        lås.withLock { _begrunnelser.append(begrunnelse) }
        if lås.withLock({ holdes }) {
            await withCheckedContinuation { c in
                let slipp = lås.withLock { () -> Bool in
                    if holdes { ventende = c; return false }
                    return true
                }
                if slipp { c.resume() }
            }
        }
        return lås.withLock { _utfall }
    }

    func slipp(_ utfall: AutentiseringsUtfall? = nil) {
        let c = lås.withLock { () -> CheckedContinuation<Void, Never>? in
            if let utfall { _utfall = utfall }
            holdes = false
            defer { ventende = nil }
            return ventende
        }
        c?.resume()
    }
}

/// Fake `send`: teller forsendelser og svarer med det testen ber om (eventuelt etter at testen slipper den).
final class FakeSend: @unchecked Sendable {
    enum Svar { case utfall(SvarUtfall), feil(TraadflataFeil), annenFeil }
    private let lås = NSLock()
    private var _kall: [(String, String)] = []
    private var svar: Svar
    private var ventende: CheckedContinuation<Void, Never>?
    private var holdes: Bool

    init(_ svar: Svar = .utfall(.avgjort), holdes: Bool = false) {
        self.svar = svar
        self.holdes = holdes
    }

    var kall: [(kortId: String, key: String)] { lås.withLock { _kall.map { (kortId: $0.0, key: $0.1) } } }

    func send(kortId: String, key: String) async throws -> SvarUtfall {
        lås.withLock { _kall.append((kortId, key)) }
        if lås.withLock({ holdes }) {
            await withCheckedContinuation { c in
                let slipp = lås.withLock { () -> Bool in
                    if holdes { ventende = c; return false }
                    return true
                }
                if slipp { c.resume() }
            }
        }
        switch lås.withLock({ svar }) {
        case .utfall(let u): return u
        case .feil(let f): throw f
        case .annenFeil: throw CancellationError()
        }
    }

    func slipp() {
        let c = lås.withLock { () -> CheckedContinuation<Void, Never>? in
            holdes = false
            defer { ventende = nil }
            return ventende
        }
        c?.resume()
    }

    var erVentende: Bool { lås.withLock { ventende != nil } }
}

final class Teller: @unchecked Sendable {
    private let lås = NSLock()
    private var n = 0
    func øk() { lås.withLock { n += 1 } }
    var verdi: Int { lås.withLock { n } }
}

@MainActor @Suite struct SvarTjenesteTests {
    private let godkjenn = Svar.Forespørsel(
        kortId: "demo-alarm", tekst: "Armere alarmen\n\nDetaljer", valg: Svarvalg(key: "approve", label: "Godkjenn")
    )
    private let avslå = Svar.Forespørsel(kortId: "demo-alarm", tekst: "Armere alarmen", valg: .avslaa)

    private func tjeneste(_ aut: FakeAutentisering, _ send: FakeSend, oppfrisk: Teller = Teller()) -> SvarTjeneste {
        SvarTjeneste(autentisering: aut, send: { try await send.send(kortId: $0, key: $1) }, oppfrisk: { oppfrisk.øk() })
    }

    /// Venter til betingelsen er sann (maks ~2 s). Oppgaver på hovedaktøren får kjøre mens vi venter.
    private func vent(_ betingelse: () -> Bool) async {
        for _ in 0..<400 where !betingelse() { try? await Task.sleep(for: .milliseconds(5)) }
    }

    // MARK: - godkjenn

    @Test func godkjennAutentisererFørDetSendes_ogOppfriskerEnGang() async {
        let aut = FakeAutentisering(.ok), send = FakeSend(), oppfrisk = Teller()
        let t = tjeneste(aut, send, oppfrisk: oppfrisk)
        t.velg(godkjenn)
        #expect(aut.antall == 0 && send.kall.isEmpty, "bekreftelsen er oppe: ingenting spurt, ingenting sendt")
        await t.bekreft()
        #expect(aut.antall == 1)
        #expect(send.kall.count == 1 && send.kall[0].kortId == "demo-alarm" && send.kall[0].key == "approve")
        #expect(t.tilstand == .ferdig(godkjenn))
        #expect(oppfrisk.verdi == 1)
    }

    @Test func begrunnelsenTilSystemdialogenErFørsteLinje() async {
        let aut = FakeAutentisering(.ok)
        let t = tjeneste(aut, FakeSend())
        t.velg(godkjenn)
        await t.bekreft()
        #expect(aut.begrunnelser == ["Godkjenn: Armere alarmen"])
    }

    @Test(arguments: [AutentiseringsUtfall.avbrutt, .utilgjengelig, .feilet])
    func autentiseringSomIkkeLykkesSenderAldri(utfall: AutentiseringsUtfall) async {
        let aut = FakeAutentisering(utfall), send = FakeSend(), oppfrisk = Teller()
        let t = tjeneste(aut, send, oppfrisk: oppfrisk)
        t.velg(godkjenn)
        await t.bekreft()
        #expect(aut.antall == 1)
        #expect(send.kall.isEmpty, "ingenting sendt uten autentisering")
        #expect(oppfrisk.verdi == 0)
        if case .sender = t.tilstand { Issue.record("kom til .sender") }
    }

    @Test func avslåHopperOverAutentiseringMenSenderDeny() async {
        let aut = FakeAutentisering(.feilet), send = FakeSend()
        let t = tjeneste(aut, send)
        t.velg(avslå)
        await t.bekreft()
        #expect(aut.antall == 0)
        #expect(send.kall.count == 1 && send.kall[0].key == "deny")
        #expect(t.tilstand == .ferdig(avslå))
    }

    @Test func bekreftUtenValgGjørIngenting() async {
        let aut = FakeAutentisering(), send = FakeSend()
        let t = tjeneste(aut, send)
        await t.bekreft()
        #expect(aut.antall == 0 && send.kall.isEmpty)
    }

    @Test func avbrytIBekreftelsenSenderIngenting() async {
        let aut = FakeAutentisering(), send = FakeSend()
        let t = tjeneste(aut, send)
        t.velg(godkjenn)
        t.lukk()
        await t.bekreft()
        #expect(aut.antall == 0 && send.kall.isEmpty && t.tilstand == .ingen)
    }

    // MARK: - single-flight

    @Test func dobbelttrykkMensDetSendesGirEnForsendelse() async {
        let aut = FakeAutentisering(.ok), send = FakeSend(holdes: true)
        let t = tjeneste(aut, send)
        t.velg(godkjenn)
        let første = Task { await t.bekreft() }
        await vent { send.erVentende }
        #expect(t.tilstand.erSender)
        // Flere trykk og nye valg mens forespørselen er ute:
        await t.bekreft()
        await t.bekreft()
        t.velg(avslå)
        t.velg(godkjenn)
        await t.bekreft()
        send.slipp()
        await første.value
        #expect(send.kall.count == 1, "nøyaktig én forsendelse")
        #expect(aut.antall == 1)
        #expect(t.tilstand == .ferdig(godkjenn))
    }

    @Test func dobbelttrykkMensSystemdialogenErOppeGirEnAutentisering() async {
        let aut = FakeAutentisering(.ok, holdes: true), send = FakeSend()
        let t = tjeneste(aut, send)
        t.velg(godkjenn)
        let første = Task { await t.bekreft() }
        await vent { aut.antall == 1 }
        await t.bekreft()
        await t.bekreft()
        #expect(aut.antall == 1)
        aut.slipp()
        await første.value
        #expect(send.kall.count == 1)
    }

    @Test func autentiseringenAvbruttMedLukkOgDeretterOkSenderIkke() async {
        let aut = FakeAutentisering(.ok, holdes: true), send = FakeSend()
        let t = tjeneste(aut, send)
        t.velg(godkjenn)
        let første = Task { await t.bekreft() }
        await vent { aut.antall == 1 }
        t.lukk()  // brukeren lukker mens dialogen er oppe
        aut.slipp(.ok)  // og dialogen svarer «ok» likevel
        await første.value
        #expect(send.kall.isEmpty, "et ok for et forlatt forsøk sender ingenting")
        #expect(t.tilstand == .ingen)
    }

    // MARK: - ingen blind retry

    @Test(arguments: [FakeSend.Svar.feil(.nettverk("tidsavbrudd")), .feil(.http(status: 503, melding: nil)), .annenFeil])
    func forespørselUtenSvarGirUsikkertOgEnForsendelse(svar: FakeSend.Svar) async {
        let aut = FakeAutentisering(.ok), send = FakeSend(svar), oppfrisk = Teller()
        let t = tjeneste(aut, send, oppfrisk: oppfrisk)
        t.velg(godkjenn)
        await t.bekreft()
        #expect(send.kall.count == 1, "ingen automatisk retry")
        #expect(t.tilstand == .usikker(godkjenn))
        #expect(oppfrisk.verdi == 1, "Nå hentes på nytt (én gang)")
        // Å trykke bekreft igjen gjør ingenting; heller ikke et nytt valg før brukeren har kvittert.
        await t.bekreft()
        t.velg(godkjenn)
        await t.bekreft()
        #expect(send.kall.count == 1 && aut.antall == 1)
        t.lukk()
        #expect(t.tilstand == .ingen)
    }

    @Test func nyttForsøkEtterKvitteringSenderEnGangTil_bevisst() async {
        let aut = FakeAutentisering(.ok), send = FakeSend(.feil(.nettverk("x")))
        let t = tjeneste(aut, send)
        t.velg(godkjenn)
        await t.bekreft()
        t.lukk()
        t.velg(godkjenn)
        await t.bekreft()
        #expect(aut.antall == 2, "et nytt, bevisst forsøk krever ny autentisering")
        #expect(send.kall.count == 2)
    }

    // MARK: - utfall

    @Test func status409OppfriskerOgViserNorskMelding() async {
        let send = FakeSend(.utfall(.alleredeAvgjort("kortet er allerede avslått"))), oppfrisk = Teller()
        let t = tjeneste(FakeAutentisering(), send, oppfrisk: oppfrisk)
        t.velg(avslå)
        await t.bekreft()
        #expect(t.tilstand == .feil(.alleredeAvgjort("kortet er allerede avslått")))
        #expect(oppfrisk.verdi == 1)
        #expect(send.kall.count == 1)
    }

    @Test func status404OppfriskerOgViserNorskMelding() async {
        let oppfrisk = Teller()
        let t = tjeneste(FakeAutentisering(), FakeSend(.utfall(.ukjentKort)), oppfrisk: oppfrisk)
        t.velg(avslå)
        await t.bekreft()
        #expect(t.tilstand == .feil(.ukjentKort))
        #expect(oppfrisk.verdi == 1)
    }

    @Test func status400GirFeilUtenOppfriskning() async {
        let oppfrisk = Teller()
        let t = tjeneste(FakeAutentisering(), FakeSend(.utfall(.ugyldigValg)), oppfrisk: oppfrisk)
        t.velg(avslå)
        await t.bekreft()
        #expect(t.tilstand == .feil(.ugyldigValg))
        #expect(oppfrisk.verdi == 0)
    }

    @Test func status401GirKreverNyttTokenUtenOppfriskning() async {
        let oppfrisk = Teller()
        let t = tjeneste(FakeAutentisering(), FakeSend(.feil(.ikkeInnlogget)), oppfrisk: oppfrisk)
        t.velg(avslå)
        await t.bekreft()
        #expect(t.tilstand == .feil(.kreverNyttToken))
        #expect(t.svar.tilstand == t.tilstand)
        #expect(oppfrisk.verdi == 0)
    }

    @Test func ugyldigKortIdNårAldriAutentiseringEllerNettverk() async {
        let aut = FakeAutentisering(), send = FakeSend()
        let t = tjeneste(aut, send)
        t.velg(Svar.Forespørsel(kortId: "../api/naa", tekst: "x", valg: Svarvalg(key: "approve", label: "Godkjenn")))
        await t.bekreft()
        #expect(aut.antall == 0 && send.kall.isEmpty)
        #expect(t.tilstand == .feil(.ugyldigKort))
    }
}

extension Svar.Tilstand {
    fileprivate var erSender: Bool {
        if case .sender = self { return true }
        return false
    }
}
