import Foundation
import LocalAuthentication
import AppCore

/// Den ekte lokale autentiseringen: `LAContext` med `.deviceOwnerAuthentication` (Face ID/Touch ID, med enhetens
/// kode som reserve). Kompilerer for iOS og macOS. Høyrisiko godtas bare fra en opplåst enhet: er det ingen
/// biometri og ingen kode, er svaret `.utilgjengelig` og ingenting sendes.
///
/// Ny `LAContext` per kall og ingen gjenbruk av en tidligere autentisering (`touchIDAuthenticationAllowableReuseDuration`
/// står på standard 0): hvert Godkjenn spør på nytt.
/// Begrunnelsen kommer fra kalleren og inneholder første linje av kortteksten, aldri tokenet.
struct LokalAutentisering: Autentisering {
    func autentiser(begrunnelse: String) async -> AutentiseringsUtfall {
        let kontekst = LAContext()
        var feil: NSError?
        guard kontekst.canEvaluatePolicy(.deviceOwnerAuthentication, error: &feil) else {
            return Self.utfall(for: feil.flatMap { LAError.Code(rawValue: $0.code) })
        }
        do {
            let ok = try await kontekst.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: begrunnelse)
            return ok ? .ok : .feilet
        } catch let e as LAError {
            return Self.utfall(for: e.code)
        } catch {
            return .feilet
        }
    }

    /// LAError → norsk-vennlig utfall. Alt som ikke er et uttrykkelig «ja» er et «nei».
    static func utfall(for kode: LAError.Code?) -> AutentiseringsUtfall {
        switch kode {
        case .userCancel, .systemCancel, .appCancel:
            return .avbrutt
        case .passcodeNotSet, .biometryNotAvailable, .biometryNotEnrolled:
            return .utilgjengelig
        default:
            // authenticationFailed, userFallback uten kode, invalidContext, notInteractive, ukjent: ingenting sendes.
            return kode == nil ? .utilgjengelig : .feilet
        }
    }
}

#if DEBUG
/// Bare DEBUG: `--auto-godkjenn` erstatter systemdialogen med denne, slik at flyten kan kjøres og fotograferes på en
/// simulator uten biometri. Finnes ikke i release (hele typen er vernet bak `#if DEBUG`, og bruken likeså).
struct AutoAutentisering: Autentisering {
    func autentiser(begrunnelse: String) async -> AutentiseringsUtfall { .ok }
}
#endif

/// Hvilken autentisering appen bruker. I release alltid den ekte. I DEBUG erstattes den av en som alltid lykkes BARE når
/// kilden er en demo og `--auto-godkjenn` er gitt: mot en live kilde er svaret alltid `LokalAutentisering`, så et glemt
/// argument (eller en agent som styrer UI) aldri kan godkjenne noe ekte uten biometri.
func velgAutentisering(argumenter: [String], valg: KildeValg) -> any Autentisering {
    #if DEBUG
    if KildeValg.brukerAutoGodkjenn(argumenter: argumenter, tillatLive: true, valg: valg) { return AutoAutentisering() }
    #endif
    return LokalAutentisering()
}
