import SwiftUI
import AppCore

@main
struct TemplateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    #if os(iOS)
    private let platform = "iOS"
    #else
    private let platform = "macOS"
    #endif

    var body: some View {
        VStack(spacing: 8) {
            Text(Greeting.message(for: platform))
                .font(.title)
                .accessibilityIdentifier("greetingLabel")
            Text("versjon \(BuildInfo.version)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("versionLabel")
        }
        .padding()
    }
}
