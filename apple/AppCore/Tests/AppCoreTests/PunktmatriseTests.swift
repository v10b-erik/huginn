import Testing
@testable import AppCore

@Suite struct PunktmatriseTests {
    @Test func alleSifreErSyvRaderAvFemKolonner() {
        for tegn in "0123456789" {
            let m = Punktmatrise.rader(for: tegn)
            #expect(m.count == 7, "«\(tegn)» har \(m.count) rader")
            #expect(m.allSatisfy { $0.count == 5 }, "«\(tegn)» har en rad som ikke er 5 kolonner")
            #expect(m.joined().contains(true), "«\(tegn)» har ingen lys prikk")
        }
    }

    @Test func nullOgåttErUlike() {
        #expect(Punktmatrise.rader(for: "0") != Punktmatrise.rader(for: "8"))
    }

    @Test func alleSifreErHverandresUlikeSomMønster() {
        let alle = "0123456789".map { Punktmatrise.rader(for: $0) }
        for i in alle.indices { for j in alle.indices where i < j { #expect(alle[i] != alle[j]) } }
    }

    @Test func nullErDenReneRingenUtenDiagonal() {
        let rader = Punktmatrise.rader(for: "0").map { $0.map { $0 ? "#" : "." }.joined() }
        #expect(rader == [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."])
    }

    @Test func ukjentTegnErTomtMønsterMenFortsattRiktigFormat() {
        let m = Punktmatrise.rader(for: "x")
        #expect(m.count == 7 && m.allSatisfy { $0.count == 5 })
        #expect(!m.joined().contains(true))
    }

    @Test func breddeTarMedMellomrom() {
        #expect(Punktmatrise.bredde(antallTegn: 0) == 0)
        #expect(Punktmatrise.bredde(antallTegn: 1) == 5)
        #expect(Punktmatrise.bredde(antallTegn: 2) == 11)
    }
}
