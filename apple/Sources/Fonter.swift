import SwiftUI
import CoreText
import AppCore

/// Fontene følger med appen som ressurser (apple/Resources/Fonts) og registreres ved oppstart for hele
/// prosessen. Det er robust på begge plattformer og trenger ingen Info.plist-liste.
enum Fonter {
    /// PostScript-navnene (apple/Resources/Fonts/FONTER.md). `Font.custom` med et navn som ikke finnes
    /// faller STILLE tilbake til systemfonten, så `erLastet` brukes av en test og en oppstartssjekk.
    enum Navn {
        static let archivoBold = "ArchivoRoman-Bold"
        static let archivoMedium = "ArchivoRoman-Medium"
        static let martianRegular = "MartianMono-Regular"
        static let martianSemiBold = "MartianMono-SemiBold"
        static let alle = [archivoBold, archivoMedium, martianRegular, martianSemiBold]
    }

    nonisolated(unsafe) private static var registrert = false

    /// Idempotent. Returnerer navnene som IKKE lot seg bruke etterpå (tom = alt i orden).
    @discardableResult
    static func registrer(bundle: Bundle = .main) -> [String] {
        if !registrert {
            registrert = true
            for url in bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
                // Feiler stille hvis den allerede er registrert (f.eks. app + testvert).
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        return Navn.alle.filter { !erLastet($0) }
    }

    /// Sant bare når CoreText faktisk leverte DENNE fonten, ikke en reserve.
    static func erLastet(_ postScriptNavn: String) -> Bool {
        let f = CTFontCreateWithName(postScriptNavn as CFString, 12, nil)
        return (CTFontCopyPostScriptName(f) as String) == postScriptNavn
    }
}

/// Typografien fra tokens (`Theme.Typografi`), som SwiftUI-stiler. Størrelsene skalerer med Dynamic Type
/// (`relativeTo`), linjehøyden og sperringen følger tokenene.
struct SkriftStil {
    enum Familie {
        case visningBold, visningMedium, monoRegular, monoSemiBold
        var navn: String {
            switch self {
            case .visningBold: Fonter.Navn.archivoBold
            case .visningMedium: Fonter.Navn.archivoMedium
            case .monoRegular: Fonter.Navn.martianRegular
            case .monoSemiBold: Fonter.Navn.martianSemiBold
            }
        }
    }

    let familie: Familie
    let str: Double
    let linjehoyde: Double?
    let sperring: Double  // em
    let relativTil: Font.TextStyle
    var versaler = false

    var font: Font { .custom(familie.navn, size: str, relativeTo: relativTil) }

    /// Ekstra avstand mellom linjer så linjehøyden blir tokenets, gitt fontens naturlige linjehøyde.
    var linjeavstand: Double {
        guard let linjehoyde else { return 0 }
        let f = CTFontCreateWithName(familie.navn as CFString, str, nil)
        let naturlig = CTFontGetAscent(f) + CTFontGetDescent(f) + CTFontGetLeading(f)
        return linjehoyde - naturlig
    }

    typealias T = Theme.Typografi

    static let hero = SkriftStil(familie: .visningBold, str: T.Str.hero, linjehoyde: T.Lh.hero, sperring: T.Sperring.hero, relativTil: .largeTitle, versaler: true)
    static let tall = SkriftStil(familie: .visningBold, str: T.Str.tall, linjehoyde: T.Lh.tall, sperring: T.Sperring.hero, relativTil: .largeTitle)
    static let h2 = SkriftStil(familie: .visningBold, str: T.Str.h2, linjehoyde: T.Lh.h2, sperring: T.Sperring.hero, relativTil: .title)
    static let tekst = SkriftStil(familie: .visningMedium, str: T.Str.tekst, linjehoyde: T.Lh.tekst, sperring: 0, relativTil: .body)
    static let etikett = SkriftStil(familie: .monoRegular, str: T.Str.etikett, linjehoyde: T.Lh.etikett, sperring: T.Sperring.etikett, relativTil: .caption, versaler: true)
    static let etikettAksent = SkriftStil(familie: .monoSemiBold, str: T.Str.etikett, linjehoyde: T.Lh.etikett, sperring: T.Sperring.etikett, relativTil: .caption, versaler: true)
    /// Små tekniske ting: tider, sha, stier. Aldri versaler (identitet regel 5).
    static let tid = SkriftStil(familie: .monoRegular, str: T.Str.tid, linjehoyde: T.Lh.tid, sperring: 0, relativTil: .caption)
    /// Liten teknisk linje under en tittel (ikke versaler).
    static let undertekst = SkriftStil(familie: .monoRegular, str: T.Str.etikett, linjehoyde: T.Lh.etikett, sperring: 0, relativTil: .caption)
    static let status = SkriftStil(familie: .monoSemiBold, str: T.Str.tid, linjehoyde: T.Lh.tid, sperring: T.Sperring.status, relativTil: .caption, versaler: true)
    static let fot = SkriftStil(familie: .monoRegular, str: T.Str.etikett, linjehoyde: T.Lh.etikett, sperring: T.Sperring.status, relativTil: .caption)
    static let knapp = SkriftStil(familie: .monoSemiBold, str: T.Str.knapp, linjehoyde: T.Lh.knapp, sperring: T.Sperring.knapp, relativTil: .callout, versaler: true)
    static let tab = SkriftStil(familie: .monoSemiBold, str: T.Str.etikett, linjehoyde: T.Lh.etikett, sperring: T.Sperring.knapp, relativTil: .caption, versaler: true)
}

extension View {
    func skrift(_ stil: SkriftStil) -> some View {
        self.font(stil.font)
            .tracking(stil.sperring * stil.str)
            .lineSpacing(stil.linjeavstand)
            .textCase(stil.versaler ? .uppercase : nil)
    }
}
