public enum BuildInfo {
    /// Erstattes med git-sha av Scripts/remote-test.sh i byggetreet på draupnir
    /// (aldri i git — lokalt tre forblir rent). «dev» = bygget utenom riggen.
    private static let raw = "BUILD_VERSION_PLACEHOLDER"

    public static var version: String {
        raw.hasPrefix("BUILD_") ? "dev" : raw
    }
}
