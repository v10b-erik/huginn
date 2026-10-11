import Foundation
import Testing
@testable import AppCore

func utcKalender() -> Calendar {
    var k = Calendar(identifier: .gregorian)
    k.timeZone = TimeZone(identifier: "UTC")!
    k.locale = Locale(identifier: "nb_NO")
    return k
}

func isoDato(_ iso: String) -> Date {
    try! Date(iso, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: iso.contains(".")))
}

@Suite struct TidTests {
    private let nå = isoDato("2026-10-11T15:52:00Z")  // en søndag

    @Test func relativTidRundesNedOgVelgerEnhet() {
        func r(_ sekunder: TimeInterval) -> String { Tid.relativ(fra: nå.addingTimeInterval(-sekunder), til: nå) }
        #expect(r(0) == "nå")
        #expect(r(59) == "nå")
        #expect(r(60) == "1 min")
        #expect(r(192) == "3 min")
        #expect(r(480) == "8 min")
        #expect(r(3599) == "59 min")
        #expect(r(3600) == "1 t")
        #expect(r(3600 * 23 + 3599) == "23 t")
        #expect(r(86_400 * 2 + 5) == "2 d")
    }

    @Test func framtidRegnesSomNå() {
        #expect(Tid.relativ(fra: nå.addingTimeInterval(500), til: nå) == "nå")
    }

    @Test func klokkeFormatererTimerMinutterSekunder() {
        #expect(Tid.klokke(sekunder: 192) == "00:03:12")
        #expect(Tid.klokke(sekunder: 3661) == "01:01:01")
        #expect(Tid.klokke(sekunder: -5) == "00:00:00")
    }

    @Test func datolinjeHarUkedagOgDatoUtenKlokkeslett() {
        #expect(Tid.datolinje(nå: nå, kalender: utcKalender()) == "Søndag 11. okt")
    }

    @Test func datolinjeFølgerKalenderensTidssone() {
        var oslo = utcKalender()
        oslo.timeZone = TimeZone(identifier: "Europe/Oslo")!
        #expect(Tid.datolinje(nå: isoDato("2026-10-11T23:30:00Z"), kalender: oslo) == "Mandag 12. okt")  // CEST: over midnatt
        #expect(Tid.hhmm(nå, kalender: oslo) == "17:52")
    }

    @Test func ikkeGregorianskKalenderKanIkkeGåUtenforTabellene() {
        // Den hebraiske kalenderen har 13 måneder og 7 ukedager med annen nummerering; vi bruker alltid gregoriansk.
        var hebraisk = Calendar(identifier: .hebrew)
        hebraisk.timeZone = TimeZone(identifier: "UTC")!
        #expect(Tid.datolinje(nå: isoDato("2026-10-11T12:00:00Z"), kalender: hebraisk) == "Søndag 11. okt")
        #expect(Tid.dagOgTid(isoDato("2027-03-30T08:30:00Z"), nå: nå, kalender: hebraisk) == "30. mar 08:30")
    }

    @Test func sidenViserDagBareNårDetIkkeErIDag() {
        let k = utcKalender()
        func s(_ iso: String) -> String { Tid.siden(isoDato(iso), nå: nå, kalender: k) }
        #expect(s("2026-10-11T03:10:00Z") == "siden 03:10")
        #expect(s("2026-10-10T22:00:00Z") == "siden i går 22:00")
        #expect(s("2026-10-08T22:00:00Z") == "siden tor 22:00")
        #expect(s("2026-10-01T22:00:00Z") == "siden 1. okt 22:00")
    }

    @Test func dagOgTidVelgerDagsuttrykk() {
        let k = utcKalender()
        func d(_ iso: String, heleDagen: Bool = false) -> String {
            Tid.dagOgTid(isoDato(iso), nå: nå, heleDagen: heleDagen, kalender: k)
        }
        #expect(d("2026-10-11T18:00:00Z") == "I dag 18:00")
        #expect(d("2026-10-12T08:30:00Z") == "I morgen 08:30")
        #expect(d("2026-10-14T08:30:00Z") == "Ons 08:30")
        #expect(d("2026-10-17T08:30:00Z") == "Lør 08:30")
        #expect(d("2026-10-18T08:30:00Z") == "18. okt 08:30")
        #expect(d("2026-10-13T00:00:00Z", heleDagen: true) == "Tir")
    }
}
