public enum Greeting {
    /// Hello-world-logikken for malen. Erstattes av ekte domenelogikk i produkter.
    public static func message(for platform: String) -> String {
        "Hello v.2 from \(Produkt.visningsnavn) on \(platform) — OTA fra ygg"
    }
}
