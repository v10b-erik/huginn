import SwiftUI
import AppCore

/// Bro fra de genererte tokenene (AppCore/Theme.swift) til SwiftUI. Selve verdiene bor i design/tokens.css.
extension Color {
    init(_ c: Theme.RGBA) {
        self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }
}

extension Theme {
    /// Palett for gjeldende modus. Appen følger systemet.
    static func palett(for scheme: ColorScheme) -> Palette {
        scheme == .dark ? mork : lys
    }
}
