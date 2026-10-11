import Foundation
import Security
import AppCore

/// Tilkoblingen i Keychain, og ingen andre steder: ikke `UserDefaults`, ikke fil, ikke logg.
/// Generisk passord (`service` + `account`), verdi = JSON `{adresse, token}`. Tilgjengelig etter første opplåsing,
/// bare på denne enheten, ikke iCloud-synk. Feil bærer bare `OSStatus`, aldri verdier.
struct KeychainLager: TilkoblingLager, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    static let standardService = "no.huginn.traadflata"
    static let standardAccount = "tilkobling"

    let service: String
    let account: String
    let tillatHttpLoopback: Bool

    init(service: String = standardService, account: String = standardAccount, tillatHttpLoopback: Bool = false) {
        self.service = service
        self.account = account
        self.tillatHttpLoopback = tillatHttpLoopback
    }

    var description: String { "KeychainLager(\(service))" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: ["service": service, "account": account]) }

    /// Nøkkelen som identifiserer elementet (brukes av alle tre operasjoner).
    private var element: [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
        ]
        #if os(macOS)
        // Data protection-keychainen, ikke den gamle filbaserte (som har en tilgangsdialog per app).
        q[kSecUseDataProtectionKeychain as String] = true
        #endif
        return q
    }

    private static let attributter: [String: Any] = [
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ]

    func les() throws -> Tilkobling? {
        var q = element
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var svar: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &svar)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw LagerFeil.keychain(status: status) }
        guard let data = svar as? Data else { throw LagerFeil.ugyldigInnhold }
        return try Tilkobling.fra(json: data, tillatHttpLoopback: tillatHttpLoopback)
    }

    /// Oppdater-eller-legg-til. `SecItemUpdate` er atomisk per element: feiler den, ligger det gamle der uendret.
    func lagre(_ tilkobling: Tilkobling) throws {
        let data = try tilkobling.json()
        var oppdatering = Self.attributter
        oppdatering[kSecValueData as String] = data
        let status = SecItemUpdate(element as CFDictionary, oppdatering as CFDictionary)
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var ny = element
            ny.merge(oppdatering) { _, nyVerdi in nyVerdi }
            let lagt = SecItemAdd(ny as CFDictionary, nil)
            guard lagt == errSecSuccess else { throw LagerFeil.keychain(status: lagt) }
        default:
            throw LagerFeil.keychain(status: status)
        }
    }

    func slett() throws {
        let status = SecItemDelete(element as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw LagerFeil.keychain(status: status) }
    }
}
