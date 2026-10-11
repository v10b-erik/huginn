// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "AppCore", targets: ["AppCore"])
    ],
    targets: [
        .target(name: "AppCore"),
        .testTarget(
            name: "AppCoreTests",
            dependencies: ["AppCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
