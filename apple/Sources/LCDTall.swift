import SwiftUI
import AppCore

/// Punktmatrise-tallet (5×7), signaturen i identiteten. Tegnes i en Canvas: lys prikk = `lys`, slukket
/// prikk = `slukket` (tomt spor). I mørk modus gløder de lyse prikkene svakt, bare når `glod` er satt.
struct LCDTall: View {
    var tekst: String
    var pitch: Double = Theme.Lcd.pitchHero
    var lys: Color
    var slukket: Color
    var glod: Color? = nil

    private var antall: Int { tekst.count }
    /// Luft rundt matrisen så gløden ikke klippes av rammen.
    private let luft = 12.0
    private var bredde: Double { Double(Punktmatrise.bredde(antallTegn: antall)) * pitch }
    private var hoyde: Double { Double(Punktmatrise.rader) * pitch }

    var body: some View {
        Canvas { ctx, _ in
            let r = pitch * Theme.Lcd.prikkRadius
            func prikk(_ ch: Character, _ i: Int, lysePrikker: Bool, _ c: inout GraphicsContext, _ farge: Color) {
                for (y, rad) in Punktmatrise.rader(for: ch).enumerated() {
                    for (x, tent) in rad.enumerated() where tent == lysePrikker {
                        let kol = i * (Punktmatrise.kolonner + Punktmatrise.mellomrom) + x
                        let cx = (Double(kol) + 0.5) * pitch, cy = (Double(y) + 0.5) * pitch
                        c.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)), with: .color(farge))
                    }
                }
            }
            var c = ctx
            c.translateBy(x: luft, y: luft)
            for (i, ch) in tekst.enumerated() { prikk(ch, i, lysePrikker: false, &c, slukket) }
            c.drawLayer { lag in
                if let glod { lag.addFilter(.shadow(color: glod, radius: 5, x: 0, y: 0)) }
                var l = lag
                for (i, ch) in tekst.enumerated() { prikk(ch, i, lysePrikker: true, &l, lys) }
            }
        }
        .frame(width: bredde + 2 * luft, height: hoyde + 2 * luft)
        .padding(-luft)
        .accessibilityHidden(true)  // verdien leses av heroens etikett, ikke som prikker
    }
}
