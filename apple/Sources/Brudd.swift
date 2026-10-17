import Foundation

extension String {
    /// Mykt brudd for VISNING: en nullbreddes mellomrom etter «:», «-», «/» og «_», så en identifikator brekker ved
    /// skilletegnene og ikke midt i et ord. Bare i view-laget: data og VoiceOver-tekst (`accessibilityLabel`) er uten.
    var medMyktBrudd: String {
        var ut = ""
        ut.reserveCapacity(count + count / 4)
        for ch in self {
            ut.append(ch)
            if ":-/_".contains(ch) { ut.append("\u{200B}") }
        }
        return ut
    }
}

extension String {
    /// «6 tråder · 30 d» brekker bare FØR midtprikken (aldri etter den, og aldri så «30» eller «d» blir en stubb): alt fra og
    /// med « · » er sammenhengende med hardt mellomrom. Bare for visning.
    var medHardeMellomrom: String {
        guard let r = range(of: " · ") else { return self }
        let hale = self[r.upperBound...].replacingOccurrences(of: " ", with: "\u{00A0}")
        return String(self[..<r.lowerBound]) + " ·\u{00A0}" + hale
    }
}
