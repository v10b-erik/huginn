import SwiftUI
import AppCore

/// Liste i glass (avvik, ventende, tråder): sperret overskrift, så rader med lampe, tittel og tilstand.
struct Listebrikke: View {
    /// En gruppe rader under en egen etikett («Venter på deg»). Uten etikett er gruppen bare radene.
    struct Gruppe: Identifiable {
        var etikett: String?
        var rader: [NaaSkjerm.Rad]
        var id: String { etikett ?? "-" }
    }

    var tittel: String
    var hoyre: String? = nil
    var rader: [NaaSkjerm.Rad]
    /// Rader i grupper med etiketter (erstatter `rader` når den er satt).
    var grupper: [Gruppe]? = nil
    /// Vises når listen er tom (tråder), ellers utelates hele brikken av kalleren.
    var tomTekst: String? = nil
    /// Henter: skjelettrader i samme brikke og med samme radhøyde, så ingenting hopper når data kommer.
    var skjelett = false
    var idPrefiks: String
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    private static let skjelettRad = NaaSkjerm.Rad(
        id: "skjelett", tittel: "eksempel-tråd-navn", undertekst: "00.00 eksempel", ord: "PARKERT", tid: "00 min", tone: .dempet,
        tittelLinjer: 1
    )

    var body: some View {
        let p = Theme.palett(for: scheme)
        Brikke(padding: EdgeInsets(top: Theme.Avstand.s4, leading: Theme.Avstand.s5, bottom: Theme.Avstand.s3, trailing: Theme.Avstand.s5)) {
            VStack(alignment: .leading, spacing: 0) {
                overskrift(p)
                    .padding(.bottom, Theme.Avstand.s3)
                    .accessibilityAddTraits(.isHeader)
                // Strek under overskriften, som i prototypen (første rad har alltid en strek over seg).
                Rectangle().fill(Color(p.kant)).frame(height: 1)

                if skjelett {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(0..<3, id: \.self) { i in
                            if i > 0 { Rectangle().fill(Color(p.kant)).frame(height: 1) }
                            RadView(rad: Self.skjelettRad)
                        }
                    }
                    .redacted(reason: .placeholder)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Henter tråder")
                    .accessibilityIdentifier(idPrefiks + "Skjelett")
                } else if rader.isEmpty, let tomTekst {
                    Text(tomTekst).skrift(.tekst).foregroundStyle(Color(p.dempet))
                        .padding(.vertical, Theme.Avstand.s3)
                        .accessibilityIdentifier(idPrefiks + "Tom")
                }
                innhold(p)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(idPrefiks)
    }

    /// Overskrift og tall: side om side, med minsteavstand. Fra AX-størrelsene brekker tallet til egen linje.
    @ViewBuilder private func overskrift(_ p: Theme.Palette) -> some View {
        if typeSize.isAccessibilitySize, hoyre != nil {
            VStack(alignment: .leading, spacing: Theme.Avstand.s1) {
                Text(tittel).skrift(.etikett).foregroundStyle(Color(p.dempet))
                if let hoyre { Text(hoyre).skrift(.tid).foregroundStyle(Color(p.dempet)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Avstand.s3) {
                Text(tittel).skrift(.etikett).foregroundStyle(Color(p.dempet))
                    .lineLimit(2).layoutPriority(1)
                Spacer(minLength: Theme.Avstand.s3)
                if let hoyre { Text(hoyre).skrift(.tid).foregroundStyle(Color(p.dempet)).lineLimit(1).fixedSize() }
            }
        }
    }

    @ViewBuilder private func innhold(_ p: Theme.Palette) -> some View {
        let alle = grupper ?? [Gruppe(etikett: nil, rader: rader)]
        let forste = alle.firstIndex { !$0.rader.isEmpty }
        ForEach(Array(alle.enumerated()), id: \.element.id) { gi, g in
            if !g.rader.isEmpty {
                if let e = g.etikett {
                    if gi != forste { Rectangle().fill(Color(p.kant)).frame(height: 1) }
                    Text(e).skrift(.etikett).foregroundStyle(Color(p.dempet))
                        .padding(.top, Theme.Avstand.s3)
                        .accessibilityAddTraits(.isHeader)
                }
                ForEach(Array(g.rader.enumerated()), id: \.element.id) { i, rad in
                    if i > 0 { Rectangle().fill(Color(p.kant)).frame(height: 1) }
                    RadView(rad: rad)
                        .accessibilityIdentifier("\(idPrefiks)Rad\(indeks(gruppe: gi, rad: i, alle: alle))")
                }
            }
        }
    }

    /// Radens plass i hele listen (på tvers av grupper), så identifikatorene er de samme med og uten grupper.
    private func indeks(gruppe: Int, rad: Int, alle: [Gruppe]) -> Int {
        alle.prefix(gruppe).reduce(0) { $0 + $1.rader.count } + rad
    }
}

private struct RadView: View {
    var rad: NaaSkjerm.Rad
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Tidskolonnen har fast bredde (og mono-tall), så tilstandsordene står høyrejustert mot samme kant.
    @ScaledMetric(relativeTo: .caption) private var tidBredde: CGFloat = 52

    var body: some View {
        let p = Theme.palett(for: scheme)
        HStack(alignment: .center, spacing: Theme.Avstand.s3) {
            lampe(p).frame(width: 14, alignment: .leading)
            if typeSize.isAccessibilitySize {
                // Tilgjengelighetsstørrelser: ord og tid ville tatt hele bredden og klemt teksten til noen få tegn.
                // Da står de under teksten, venstrestilt: ordet først og aldri kuttet, og tiden brekker under ordet
                // når de to ikke får plass ved siden av hverandre.
                VStack(alignment: .leading, spacing: Theme.Avstand.s2) {
                    tekst(p)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Theme.Avstand.s3) {
                            ord(p)
                            tid(p).fixedSize(horizontal: true, vertical: false)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            ord(p)
                            tid(p).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Spacer(minLength: 0)
            } else {
                tekst(p)
                Spacer(minLength: Theme.Avstand.s2)
                ord(p)
                tid(p).frame(minWidth: rad.ord == nil ? nil : tidBredde, alignment: .trailing)
            }
        }
        .padding(.vertical, Theme.Avstand.s3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rad.talesTekst)
    }

    /// Lampen er FORM (identitet regel 2): fylt = du må handle (venter), ring = noe pågår, dempet fylt = ellers.
    @ViewBuilder private func lampe(_ p: Theme.Palette) -> some View {
        if rad.pågår {
            Circle().strokeBorder(lampefarge(rad.tone, p), lineWidth: 1.5)
                .frame(width: Theme.Maal.led, height: Theme.Maal.led)
        } else {
            Circle().fill(lampefarge(rad.tone, p)).frame(width: Theme.Maal.led, height: Theme.Maal.led)
        }
    }

    private func tekst(_ p: Theme.Palette) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            // Én linje kuttes i MIDTEN (halen skiller navn fra hverandre); fra AX-størrelsene brekker tittelen i to.
            // Fra AX-størrelsene kuttes ingenting: tittelen får brekke fritt (intet kuttet navn ved siden av en stor skrift).
            let linjer: Int? = typeSize.isAccessibilitySize ? nil : rad.tittelLinjer
            Text(rad.tittel).skrift(.tekst)
                .foregroundStyle(Color(p.tekst))
                .lineLimit(linjer).truncationMode(linjer == 1 ? .middle : .tail)
            if let u = rad.undertekst {
                // Håndtaket på «venter»-rader er ÉN linje (`undertekstLinjer`) og kuttes i MIDTEN, så halen som
                // skiller håndtak fra hverandre (`…-eksempel-12`) blir stående. Annen undertekst kuttes i halen.
                Text(u).skrift(.undertekst).foregroundStyle(Color(p.dempet))
                    .lineLimit(typeSize.isAccessibilitySize && rad.undertekstLinjer > 1 ? nil : rad.undertekstLinjer)
                    .truncationMode(rad.undertekstLinjer == 1 ? .middle : .tail)
            }
        }
    }

    /// Tilstandsordet (identitet regel 4: aldri farge alene) står ALLTID helt: høyeste prioritet og `fixedSize`
    /// i bredden, så det aldri blir «PÅG…». Det er teksten til venstre som kuttes, og tiden som brekker.
    @ViewBuilder private func ord(_ p: Theme.Palette) -> some View {
        if let ord = rad.ord {
            Text(ord).skrift(.status).foregroundStyle(tekstfarge(rad.tone, p))
                .lineLimit(1).fixedSize(horizontal: true, vertical: false).layoutPriority(2)
        }
    }

    /// Tiden har lavere prioritet enn ordet; i AX-grenen får den brekke under ordet i stedet for å kuttes.
    @ViewBuilder private func tid(_ p: Theme.Palette) -> some View {
        if let tid = rad.tid {
            Text(tid).skrift(.tid).monospacedDigit().foregroundStyle(Color(p.dempet))
                .layoutPriority(1)
        }
    }
}
