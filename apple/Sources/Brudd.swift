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
    /// Hardt mellomrom rundt « · », så midtprikken aldri blir stående alene på en linje ved AX. Bare for visning.
    var medHardeMellomrom: String { replacingOccurrences(of: " · ", with: "\u{00A0}·\u{00A0}") }
}
