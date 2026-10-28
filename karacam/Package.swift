// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KaracamCore",
    defaultLocalization: "tr",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KaracamCore", targets: ["KaracamCore"]),
        .library(name: "KaracamAppModel", targets: ["KaracamAppModel"]),
        .executable(name: "karacam-sim", targets: ["karacam-sim"]),
    ],
    targets: [
        .target(
            name: "KaracamCore",
            resources: [.copy("Resources/Content")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Arayüzden bağımsız uygulama durumu: SwiftUI ve StoreKit import etmez, Linux'ta da test edilir.
        .target(
            name: "KaracamAppModel",
            dependencies: ["KaracamCore"],
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
        .testTarget(
            name: "KaracamAppModelTests",
            dependencies: ["KaracamAppModel", "KaracamCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
