import SwiftUI
import AppCore

/// Glass som overflate (identitet regel 7): halvgjennomsiktig fyll, 1 pt kant, lyskant øverst. Skygge bare
/// i lys modus (tokenet `skygge` er gjennomsiktig i mørk). Radiusen kommer alltid fra `Theme.Radius`.
struct GlassFlate: ViewModifier {
    enum Variant {
        /// Vanlig glass.
        case glass
        /// Krever deg: periwinkle tone og kant (fylt flate er forbeholdt handlingsknappen).
        case krever
        /// Valgt: tonet, aldri fylt (regel 2).
        case valgt
    }

    var radius: Double
    var variant: Variant = .glass
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let p = Theme.palett(for: scheme)
        let form = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let fyll: [Color] =
            switch variant {
            case .glass: [Color(p.glass1), Color(p.glass2)]
            case .krever: [Color(p.krever1), Color(p.krever2)]
            case .valgt: [Color(p.aksentTone), Color(p.krever2)]
            }
        content
            // Skyggen hører til formen, ikke til innholdet: på containeren ville den ligget som en glorie
            // under hver tekst og hvert LCD-punkt (regel 7: glass er overflate, ikke pynt).
            .background(
                form.fill(LinearGradient(colors: fyll, startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(p.skygge), radius: 10, x: 0, y: 8)
            )
            .overlay(form.strokeBorder(variant == .glass ? Color(p.kant) : Color(p.aksentKant), lineWidth: 1))
            .overlay(
                // Lyskanten: en 1 pt strek rett innenfor kanten som bare lever øverst og fader ut nedover.
                form.inset(by: 1).strokeBorder(Color(p.kantLys), lineWidth: 1)
                    .mask(alignment: .top) {
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: radius)
                    }
                    .allowsHitTesting(false)
            )
    }
}

extension View {
    func glassFlate(radius: Double, variant: GlassFlate.Variant = .glass) -> some View {
        modifier(GlassFlate(radius: radius, variant: variant))
    }
}

/// Fargen en tone betyr, som tekst (aldri `svak`: den er ikke tekstfarge).
func tekstfarge(_ tone: NaaSkjerm.Tone, _ p: Theme.Palette) -> Color {
    switch tone {
    case .aksent: Color(p.aksent)
    case .feil: Color(p.feil)
    case .ok: Color(p.ok)
    case .dempet: Color(p.dempet)
    }
}

/// Lampe/strek-farge: som tekstfarge, bortsett fra at «dempet» her er den slukkede `svak`.
func lampefarge(_ tone: NaaSkjerm.Tone, _ p: Theme.Palette) -> Color {
    tone == .dempet ? Color(p.svak) : tekstfarge(tone, p)
}

/// Brikken: stor glassflate (radius `brikke`).
struct Brikke<Innhold: View>: View {
    var variant: GlassFlate.Variant = .glass
    var padding = EdgeInsets(top: Theme.Avstand.s4, leading: Theme.Avstand.s5, bottom: Theme.Avstand.s4, trailing: Theme.Avstand.s5)
    @ViewBuilder var innhold: Innhold

    var body: some View {
        innhold
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassFlate(radius: Theme.Radius.brikke, variant: variant)
    }
}

/// Bakgrunnen: `flateBunn` med to myke `glod`-gløder (ellipser, som i prototypen).
struct Bakgrunn: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Theme.palett(for: scheme)
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(p.flateBunn)))
            func glod(_ farge: Theme.RGBA, rx: Double, ry: Double, midtX: Double, midtY: Double) {
                let rxPt = rx * size.width, ryPt = ry * size.height
                var c = ctx
                c.translateBy(x: midtX * size.width, y: midtY * size.height)
                c.scaleBy(x: 1, y: ryPt / rxPt)
                let r = rxPt * 0.62  // gradienten er borte ved 62 % av radien
                c.fill(
                    Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)),
                    with: .radialGradient(
                        Gradient(colors: [Color(farge), Color(farge).opacity(0)]),
                        center: .zero, startRadius: 0, endRadius: r
                    )
                )
            }
            glod(p.glod1, rx: 1.2, ry: 0.47, midtX: 0.85, midtY: -0.08)
            glod(p.glod2, rx: 0.9, ry: 0.42, midtX: -0.10, midtY: 0.34)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Rad der barna deler bredden i forhold til `vekter` (knappene Godkjenn : Avslå = 3 : 2, som i prototypen).
struct Proporsjonal: Layout {
    var vekter: [Double]
    var mellomrom: Double

    private func bredder(_ total: Double, _ n: Int) -> [Double] {
        let v = Array(vekter.prefix(n))
        let ledig = max(0, total - mellomrom * Double(max(0, n - 1)))
        let sum = v.reduce(0, +)
        return v.map { ledig * $0 / sum }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let total = proposal.width ?? 300
        let b = bredder(total, subviews.count)
        let h = zip(subviews, b).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }.max() ?? 0
        return CGSize(width: total, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let b = bredder(bounds.width, subviews.count)
        var x = bounds.minX
        for (view, bredde) in zip(subviews, b) {
            view.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: bredde, height: bounds.height))
            x += bredde + mellomrom
        }
    }
}
