/// Punktmatrise-sifre 5×7 som ren data (LCD-avlesningen i identiteten, regel 3). Mønstrene er de fra
/// `design/utforskning/punkt.js`; null-en er den rene ringen. Tegningen står i `LCDTall` (App-målet).
public enum Punktmatrise {
    public static let kolonner = 5
    public static let rader = 7
    /// Tomme kolonner mellom to sifre.
    public static let mellomrom = 1

    private static let monstre: [Character: [String]] = [
        "0": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
    ]

    /// 7 rader × 5 kolonner, `true` = lys prikk. Tegn som ikke er sifre gir tomt mønster (alt slukket).
    public static func rader(for tegn: Character) -> [[Bool]] {
        guard let m = monstre[tegn] else { return Array(repeating: Array(repeating: false, count: kolonner), count: rader) }
        return m.map { $0.map { $0 == "#" } }
    }

    /// Antall kolonner et tall på `antallTegn` sifre opptar, med mellomrom mellom sifrene.
    public static func bredde(antallTegn n: Int) -> Int {
        n <= 0 ? 0 : n * kolonner + (n - 1) * mellomrom
    }
}
