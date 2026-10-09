import Testing
@testable import AppCore

@Suite struct GreetingTests {
    @Test func includesPlatformName() {
        #expect(Greeting.message(for: "iOS").contains("iOS"))
    }

    @Test func startsWithHello() {
        #expect(Greeting.message(for: "macOS").hasPrefix("Hello"))
    }
}
