import SwiftUI
import AppCore
import UserNotifications
import os
#if os(iOS)
import UIKit
#endif

/// Push i appen: tillatelse, token til trådflata og trykk-ruting. Et varsel er bare en dør: trykket åpner «Nå»,
/// og ingenting avgjøres av det (ingen kategorier med handlinger). Tokenet er en hemmelighet: det logges aldri.
@MainActor @Observable
final class PushKoordinator {
    static let shared = PushKoordinator()

    /// Miljøet APNs-tokenet gjelder for, satt av byggkonfigurasjonen (`aps-environment` er `development` i DEBUG).
    nonisolated static var miljo: PushMiljo {
        #if DEBUG
        .sandbox
        #else
        .produksjon
        #endif
    }

    /// Synsløkka (DEBUG): `--ingen-push` hopper over dialogen og registreringen, som ellers ødelegger skjermbildene.
    nonisolated static var hoppOver: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--ingen-push")
        #else
        false
        #endif
    }

    /// Til visning i arket: `abcdef…1234`, aldri hele tokenet. Tomt uten token eller uten gitt tillatelse.
    var fingeravtrykk: String? { tillatt ? token?.fingeravtrykk : nil }
    /// Kortet et trykk på et varsel vil åpne. Nullstilles av «Nå» når det er behandlet.
    private(set) var rute: String?
    /// Økes ved hvert trykk, så samme kort kan åpnes to ganger på rad.
    private(set) var rutetelling = 0
    private(set) var tillatt = false

    private var token: PushToken?
    private var klient: TraadflataKlient?
    private var sendtToken: PushToken?
    private var spoerrer = false
    private let logg = Logger(subsystem: "no.huginn", category: "push")

    /// Push og opprydding gjelder bare en live kilde (demo-«rolig» har 0 kort og ville slettet ekte varsler).
    var erLive: Bool { klient != nil }

    /// Kalles når en live tilkobling står (hver oppstart og etter ny Kobling); `nil` ellers (demo, frakoblet).
    func bruk(valg: KildeValg?) {
        guard !Self.hoppOver, case .live(let url, let t)? = valg else {
            klient = nil
            return
        }
        klient = TraadflataKlient(baseURL: url, token: t)
        sendtToken = nil
        registrer()
        sendHvisKlart()
        // En lagret live-tilkobling betyr at Kobling har skjedd: spør hvis svaret ikke er gitt.
        Task { await spoerOmNodvendig() }
    }

    /// Etter vellykket Kobling (ikke ved oppstart). Samme vei som `bruk`: spør bare når svaret ikke er gitt.
    func etterKobling() {
        Task { await spoerOmNodvendig() }
    }

    private func spoerOmNodvendig() async {
        let c = UNUserNotificationCenter.current()
        let status = Self.status(await c.notificationSettings().authorizationStatus)
        tillatt = status == .tillatt
        guard !spoerrer, PushTillatelse.skalSpoerre(status: status, erLive: erLive, hoppOver: Self.hoppOver) else { return }
        spoerrer = true
        defer { spoerrer = false }
        let granted = try? await c.requestAuthorization(options: [.alert, .sound])
        tillatt = granted == true
        logg.info("tillatelse: \(granted == true ? "gitt" : "ikke gitt", privacy: .public)")
        registrer()
    }

    nonisolated private static func status(_ s: UNAuthorizationStatus) -> PushTillatelse.Status {
        switch s {
        case .notDetermined: .ikkeAvgjort
        case .denied: .avslatt
        case .authorized, .provisional, .ephemeral: .tillatt
        @unknown default: .annet
        }
    }

    #if DEBUG
    /// Synsløkka: et syntetisk token vises i tilkoblingsarket (`--demo-push-token`).
    func visSyntetiskToken() {
        token = PushToken(hex: "abcdef" + String(repeating: "0", count: 54) + "1234")
        tillatt = true
    }
    #endif

    private func registrer() {
        #if os(iOS)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    func fikkToken(_ data: Data) {
        guard let t = PushToken(data: data) else {
            logg.error("token med uventet lengde")
            return
        }
        token = t
        sendHvisKlart()
    }

    /// Registreringen feilet (typisk simulator uten entitlement, eller ingen nett). Stille for brukeren.
    func registreringFeilet(kode: Int) {
        logg.error("registrering for push feilet (kode \(kode, privacy: .public))")
    }

    /// Ett forsøk per oppstart/tokenendring/ny tilkobling. Feiler det, prøves det ikke igjen før neste.
    private func sendHvisKlart() {
        guard let klient, let token, sendtToken != token else { return }
        sendtToken = token
        let miljo = Self.miljo
        let logg = logg
        Task.detached {
            do {
                try await klient.registrerPush(token: token, miljo: miljo)
            } catch {
                // Feiltypen bærer aldri tokenet; bare kategorien logges.
                logg.error("push-token ikke registrert: \(Self.kategori(error), privacy: .public)")
            }
        }
    }

    nonisolated private static func kategori(_ e: Error) -> String {
        switch e as? TraadflataFeil {
        case .ikkeInnlogget?: "401"
        case .http(let s, _)?: "http \(s)"
        case .nettverk?: "nettverk"
        default: "annet"
        }
    }

    // MARK: - trykk og visning

    func trykket(userInfo: [AnyHashable: Any]) {
        // Kan komme før tilkoblingen er klar (kaldstart); «Nå» avgjør om ruten gjelder (bare live kilde).
        if case .godkjenning(let id) = PushRute.parse(userInfo: userInfo) {
            rute = id
            rutetelling += 1
        }
    }

    func ruteBehandlet() { rute = nil }

    /// Etter HVER vellykket henting: fjern leverte godkjenningsvarsler som ikke finnes blant gjeldende godkjenninger
    /// (dekker kort avgjort her, i Telegram eller andre steder). Bare live.
    func rydd(gjeldende: Set<String>) {
        guard erLive else { return }
        Task {
            let c = UNUserNotificationCenter.current()
            let levert = await c.deliveredNotifications()
            let ider = levert.compactMap { n -> String? in
                guard case .godkjenning(let id) = PushRute.parse(userInfo: n.request.content.userInfo), !gjeldende.contains(id) else { return nil }
                return n.request.identifier
            }
            if !ider.isEmpty { c.removeDeliveredNotifications(withIdentifiers: ider) }
        }
    }
}

/// Varselsentralens delegat (felles for iOS og macOS). Ingen `UNNotificationCategory`: varselet har ingen handlinger.
final class VarselDelegat: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        // Bare standardhandlingen (trykk). Alt annet, inkludert dismiss, gjør ingenting.
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let info = response.notification.request.content.userInfo
        await MainActor.run { PushKoordinator.shared.trykket(userInfo: info) }
    }
}

#if os(iOS)
final class AppDelegate: NSObject, UIApplicationDelegate {
    static let delegat = VarselDelegat()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = Self.delegat
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushKoordinator.shared.fikkToken(deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        let kode = (error as NSError).code
        Task { @MainActor in PushKoordinator.shared.registreringFeilet(kode: kode) }
    }
}
#endif
