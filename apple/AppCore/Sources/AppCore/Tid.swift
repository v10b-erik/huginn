import Foundation

/// Tidsformatering som ren funksjon: `nå` og kalender sendes inn, ingenting leser klokka selv.
/// Alt er norsk og uten `DateFormatter`, så resultatet er likt på Linux og Apple og uavhengig av systemspråk.
public enum Tid {
    private static let ukedager = ["Søndag", "Mandag", "Tirsdag", "Onsdag", "Torsdag", "Fredag", "Lørdag"]
    private static let ukedagerKort = ["Søn", "Man", "Tir", "Ons", "Tor", "Fre", "Lør"]
    private static let maaneder = ["jan", "feb", "mar", "apr", "mai", "jun", "jul", "aug", "sep", "okt", "nov", "des"]

    /// Alltid gregoriansk (med kalenderens tidssone): ukedag- og månedsoppslagene under er gregorianske
    /// tabeller, og en annen kalender kunne gitt indekser utenfor dem.
    public static func gregoriansk(_ kalender: Calendar) -> Calendar {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = kalender.timeZone
        k.locale = kalender.locale
        return k
    }

    /// «nå», «3 min», «1 t», «2 d». Rundes ned. Framtid regnes som «nå».
    public static func relativ(fra: Date, til: Date) -> String {
        let s = Int(til.timeIntervalSince(fra))
        if s < 60 { return "nå" }
        if s < 3600 { return "\(s / 60) min" }
        if s < 86_400 { return "\(s / 3600) t" }
        return "\(s / 86_400) d"
    }

    /// «00:03:12». Negativt klippes til null.
    public static func klokke(sekunder: Int) -> String {
        let s = max(0, sekunder)
        return String(format: "%02d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
    }

    /// «15:52».
    public static func hhmm(_ dato: Date, kalender: Calendar) -> String {
        let k = gregoriansk(kalender).dateComponents([.hour, .minute], from: dato)
        return String(format: "%02d:%02d", k.hour ?? 0, k.minute ?? 0)
    }

    /// «Søndag 11. okt» (versaler gjør visningen). Bevisst uten klokkeslett: statuslinjen viser klokka, og et
    /// klokkeslett her ville frosset mellom hentinger.
    public static func datolinje(nå: Date, kalender: Calendar) -> String {
        let k = gregoriansk(kalender)
        let d = k.dateComponents([.day, .month], from: nå)
        return "\(ukedag(nå, kalender: k)) \(d.day ?? 1). \(maaneder[((d.month ?? 1) - 1) % 12])"
    }

    public static func ukedag(_ dato: Date, kalender: Calendar) -> String {
        ukedager[(gregoriansk(kalender).component(.weekday, from: dato) - 1) % 7]
    }

    /// «siden 03:10» samme dag, ellers med dag («siden i går 22:00», «siden fre 22:00», «siden 8. okt 22:00»).
    public static func siden(_ dato: Date, nå: Date, kalender: Calendar) -> String {
        let k = gregoriansk(kalender)
        if k.isDate(dato, inSameDayAs: nå) { return "siden \(hhmm(dato, kalender: k))" }
        let tekst = dagOgTid(dato, nå: nå, kalender: k)
        return "siden " + tekst.prefix(1).lowercased() + tekst.dropFirst()
    }

    /// «I dag 18:00», «I morgen 07:30», «I går 22:00», «Man 08:30» (innen en uke), ellers «23. okt 08:30».
    /// `heleDagen` utelater klokkeslettet.
    public static func dagOgTid(_ dato: Date, nå: Date, heleDagen: Bool = false, kalender: Calendar) -> String {
        let kalender = gregoriansk(kalender)
        let dagerTil = kalender.dateComponents(
            [.day], from: kalender.startOfDay(for: nå), to: kalender.startOfDay(for: dato)
        ).day ?? 0
        let dag: String
        switch dagerTil {
        case 0: dag = "I dag"
        case 1: dag = "I morgen"
        case -1: dag = "I går"
        case 2...6, -6 ... -2: dag = ukedagerKort[(kalender.component(.weekday, from: dato) - 1) % 7]
        default:
            let k = kalender.dateComponents([.day, .month], from: dato)
            dag = "\(k.day ?? 1). \(maaneder[((k.month ?? 1) - 1) % 12])"
        }
        return heleDagen ? dag : "\(dag) \(hhmm(dato, kalender: kalender))"
    }
}
