import Testing
import AppCore

@Suite struct AppTests {
    @Test func coreIsReachableFromAppTarget() {
        #expect(Greeting.message(for: "iOS").contains("Hello"))
    }
}
