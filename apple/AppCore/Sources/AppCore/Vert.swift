import Foundation

/// Vertsnavnet slik foten viser det («live · ygg-v1»). Foten er én linje, og et tailnett-navn
/// (`ygg-v1.tail908368.ts.net`) er mest støy: bare første ledd sier hvilken maskin det er.
///
/// - Et DNS-navn med flere ledd viser bare første ledd (`ygg-v1.tail908368.ts.net` → `ygg-v1`). Et avsluttende
///   punktum (fullt kvalifisert navn) regnes ikke som ledd. En port følger med (`ygg-v1:3449`).
/// - IPv4, IPv6, enkeltledds-verter (`localhost`) og alt annet som ikke er et vanlig DNS-navn vises uendret.
/// - Tom eller ugyldig inndata (blanke, mellomrom, `/`, `?`, `#`, `@`, kontrolltegn) gir `?`. Det betyr at en hel
///   URL, en sti eller `bruker:token@vert` aldri kan havne i foten: vi viser ingenting heller enn noe vi ikke forstår.
///
/// Ren funksjon, ingen nettverk og ingen oppslag.
public func vertVisning(_ vert: String?) -> String {
    let ukjent = "?"
    guard let vert, !vert.isEmpty else { return ukjent }
    let forbudt = CharacterSet.whitespacesAndNewlines
        .union(.controlCharacters)
        .union(CharacterSet(charactersIn: "/\\?#@"))
    guard vert.unicodeScalars.allSatisfy({ !forbudt.contains($0) }) else { return ukjent }

    // IPv6 (`::1`, `[::1]:3030`, `fe80::1`): flere kolon eller hakeparentes. Uendret.
    if vert.hasPrefix("[") || vert.filter({ $0 == ":" }).count > 1 { return vert }

    // Del av en eventuell port. `host:` uten tall er ikke en port; da er det ikke et vanlig navn, uendret.
    var navn = vert
    var port = ""
    if let kolon = vert.firstIndex(of: ":") {
        navn = String(vert[..<kolon])
        port = String(vert[kolon...])
        let siffer = port.dropFirst()
        guard !navn.isEmpty, !siffer.isEmpty, siffer.allSatisfy(\.isASCII), siffer.allSatisfy(\.isNumber) else {
            return vert
        }
    }

    var ledd = navn.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    if ledd.count > 1, ledd.last == "" { ledd.removeLast() }  // fullt kvalifisert: «ygg-v1.example.»
    guard ledd.count > 1 else { return vert }

    // IPv4 (og alt som bare er tall og punktum): siste ledd er tall, og et DNS-navn har aldri det.
    if let siste = ledd.last, siste.allSatisfy(\.isASCII), siste.allSatisfy(\.isNumber) { return vert }

    func gyldigLedd(_ l: String) -> Bool {
        guard (1...63).contains(l.count), !l.hasPrefix("-"), !l.hasSuffix("-") else { return false }
        return l.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_") }
    }
    guard ledd.allSatisfy(gyldigLedd) else { return vert }
    return ledd[0] + port
}
