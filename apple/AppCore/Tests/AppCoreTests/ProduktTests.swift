import Testing
@testable import AppCore

@Suite struct ProduktTests {
    @Test func visningsnavnErBasic() {
        #expect(Produkt.visningsnavn == "Basic")
    }

    @Test func greetingBrukerVisningsnavn() {
        #expect(Greeting.message(for: "iOS").contains(Produkt.visningsnavn))
    }
}
