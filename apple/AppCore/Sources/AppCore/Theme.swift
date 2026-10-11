// GENERERT fra design/tokens.css av Scripts/gen-theme.ts — ikke rediger for hånd.
// Endre tokens.css og kjør: bun Scripts/gen-theme.ts   (CI kjører --sjekk).
//
// Ren logikk uten SwiftUI, så den testes på Linux (swift test på ygg-v1). Farger er sRGB 0…1; App-målet
// gjør dem til Color (apple/Sources/ThemeFarge.swift). Bevegelse speiles her når en flate trenger den.

public enum Theme {
    public struct RGBA: Sendable, Equatable {
        public let r: Double, g: Double, b: Double, a: Double
        public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
            self.r = r; self.g = g; self.b = b; self.a = a
        }
    }

    /// Fargerollene (tokens.css `--farge-*`). Samme roller i begge moduser.
    public struct Palette: Sendable, Equatable {
        public let flateBunn: RGBA
        public let glod1: RGBA
        public let glod2: RGBA
        public let glass1: RGBA
        public let glass2: RGBA
        public let kant: RGBA
        public let kantLys: RGBA
        public let spor: RGBA
        public let band: RGBA
        public let tekst: RGBA
        public let dempet: RGBA
        public let svak: RGBA
        public let aksent: RGBA
        public let aksentFyll1: RGBA
        public let aksentFyll2: RGBA
        public let aksentTone: RGBA
        public let aksentKant: RGBA
        public let krever1: RGBA
        public let krever2: RGBA
        public let skygge: RGBA
        public let paAksent: RGBA
        public let feil: RGBA
        public let ok: RGBA
        public let kontrastflate: RGBA
        public let kontrastflateBand: RGBA
    }

    /// Mørk modus (standard).
    public static let mork = Palette(
        flateBunn: RGBA(0.0549, 0.0824, 0.149),
        glod1: RGBA(0.1333, 0.1843, 0.4),
        glod2: RGBA(0.0863, 0.1255, 0.3216),
        glass1: RGBA(1.0, 1.0, 1.0, 0.075),
        glass2: RGBA(1.0, 1.0, 1.0, 0.03),
        kant: RGBA(1.0, 1.0, 1.0, 0.07),
        kantLys: RGBA(1.0, 1.0, 1.0, 0.05),
        spor: RGBA(1.0, 1.0, 1.0, 0.09),
        band: RGBA(0.0, 0.0, 0.0, 0.28),
        tekst: RGBA(0.8667, 0.8863, 0.9373),
        dempet: RGBA(0.5765, 0.6118, 0.698),
        svak: RGBA(0.3608, 0.3922, 0.4745),
        aksent: RGBA(0.5059, 0.5686, 0.9098),
        aksentFyll1: RGBA(0.3529, 0.4235, 0.8392),
        aksentFyll2: RGBA(0.3098, 0.3804, 0.8),
        aksentTone: RGBA(0.5059, 0.5686, 0.9098, 0.18),
        aksentKant: RGBA(0.5059, 0.5686, 0.9098, 0.55),
        krever1: RGBA(0.5059, 0.5686, 0.9098, 0.14),
        krever2: RGBA(0.5059, 0.5686, 0.9098, 0.04),
        skygge: RGBA(0.0, 0.0, 0.0, 0.0),
        paAksent: RGBA(1.0, 1.0, 1.0),
        feil: RGBA(0.949, 0.4863, 0.4863),
        ok: RGBA(0.4353, 0.8118, 0.6353),
        kontrastflate: RGBA(0.0667, 0.0902, 0.1647),
        kontrastflateBand: RGBA(0.0824, 0.098, 0.1451)
    )

    /// Lys modus.
    public static let lys = Palette(
        flateBunn: RGBA(0.9333, 0.9451, 0.9765),
        glod1: RGBA(0.8627, 0.8902, 1.0),
        glod2: RGBA(0.9098, 0.9216, 0.9843),
        glass1: RGBA(1.0, 1.0, 1.0, 0.78),
        glass2: RGBA(1.0, 1.0, 1.0, 0.52),
        kant: RGBA(0.1569, 0.2039, 0.4314, 0.09),
        kantLys: RGBA(1.0, 1.0, 1.0, 0.9),
        spor: RGBA(0.1569, 0.2039, 0.4314, 0.1),
        band: RGBA(0.9216, 0.9333, 0.9569),
        tekst: RGBA(0.1059, 0.1294, 0.251),
        dempet: RGBA(0.3569, 0.3961, 0.502),
        svak: RGBA(0.5412, 0.5765, 0.6706),
        aksent: RGBA(0.3137, 0.3843, 0.8118),
        aksentFyll1: RGBA(0.3529, 0.4235, 0.8392),
        aksentFyll2: RGBA(0.3137, 0.3843, 0.8118),
        aksentTone: RGBA(0.3137, 0.3843, 0.8118, 0.14),
        aksentKant: RGBA(0.3137, 0.3843, 0.8118, 0.55),
        krever1: RGBA(0.3137, 0.3843, 0.8118, 0.12),
        krever2: RGBA(0.3137, 0.3843, 0.8118, 0.04),
        skygge: RGBA(0.1569, 0.2039, 0.4314, 0.22),
        paAksent: RGBA(1.0, 1.0, 1.0),
        feil: RGBA(0.7412, 0.2392, 0.2745),
        ok: RGBA(0.0863, 0.4784, 0.3059),
        kontrastflate: RGBA(0.9216, 0.9333, 0.9569),
        kontrastflateBand: RGBA(0.9216, 0.9333, 0.9569)
    )

    /// Avstandsskala (pt), 4-basert.
    public enum Avstand {
        public static let s1: Double = 4.0
        public static let s2: Double = 8.0
        public static let s3: Double = 12.0
        public static let s4: Double = 16.0
        public static let s5: Double = 24.0
    }

    /// Radiusskala (pt). Blandes aldri utenfor skalaen.
    public enum Radius {
        public static let brikke: Double = 28.0
        public static let knapp: Double = 18.0
        public static let band: Double = 16.0
        public static let chip: Double = 14.0
        public static let strek: Double = 999.0
    }

    /// Mål (pt).
    public enum Maal {
        public static let knapp: Double = 56.0
        public static let tab: Double = 60.0
        public static let beroringMin: Double = 44.0
        public static let led: Double = 7.0
        public static let bar: Double = 5.0
        public static let segment: Double = 6.0
    }

    /// LCD-avlesningen: punktmatrise 5×7.
    public enum Lcd {
        public static let pitchHero: Double = 15.0
        public static let prikkRadius: Double = 0.39
    }

    /// Varigheter (sekunder). Kurven (--easing-ut) er ikke et tall og velges i viewet.
    public enum Varighet {
        public static let knapp: Double = 0.12
        public static let brikke: Double = 0.25
        public static let ark: Double = 0.35
    }

    /// Typografi: størrelser og linjehøyder i pt, sperring i em, vekt som CSS-tall (400…700).
    /// Skriftfamiliene er ikke tall og følger med appen (apple/Resources/Fonts/FONTER.md).
    public enum Typografi {
        /// Skriftvekt (CSS-tall).
        public enum Vekt {
            public static let stor: Double = 700.0
            public static let tekst: Double = 500.0
            public static let etikett: Double = 400.0
            public static let etikettAksent: Double = 600.0
        }

        /// Skriftstørrelse (pt).
        public enum Str {
            public static let hero: Double = 40.0
            public static let tall: Double = 38.0
            public static let h2: Double = 26.0
            public static let tekst: Double = 15.0
            public static let etikett: Double = 10.5
            public static let stegetikett: Double = 9.0
            public static let knapp: Double = 12.5
            public static let tid: Double = 12.0
        }

        /// Linjehøyde (pt).
        public enum Lh {
            public static let hero: Double = 38.0
            public static let tall: Double = 42.0
            public static let h2: Double = 30.0
            public static let tekst: Double = 22.0
            public static let etikett: Double = 16.0
            public static let stegetikett: Double = 12.0
            public static let knapp: Double = 16.0
            public static let tid: Double = 16.0
        }

        /// Bokstavsperring (em, multipliseres med skriftstørrelsen).
        public enum Sperring {
            public static let etikett: Double = 0.14
            public static let knapp: Double = 0.14
            public static let hero: Double = -0.01
            public static let status: Double = 0.06
        }
    }
}
