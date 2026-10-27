// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KaracamCore",
    defaultLocalization: "tr",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KaracamCore", targets: ["KaracamCore"]),
        .executable(name: "karacam-sim", targets: ["karacam-sim"]),
    ],
    targets: [
        .target(
            name: "KaracamCore",
            resources: [.copy("Resources/Content")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "karacam-sim",
            dependencies: ["KaracamCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "KaracamCoreTests",
            dependencies: ["KaracamCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
