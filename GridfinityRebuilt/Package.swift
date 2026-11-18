// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "GridfinityRebuilt",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GridfinityRebuilt", targets: ["GridfinityRebuilt"]),
        .library(name: "GridfinityTestSupport", targets: ["GridfinityTestSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tomasf/Cadova.git", from: "1.3.0"),
        // .package(path: "../../../Cadova/Cadova"),
    ],
    targets: [
        .target(
            name: "GridfinityRebuilt",
            dependencies: ["Cadova"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .target(
            name: "GridfinityTestSupport",
            dependencies: ["Cadova"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .testTarget(
            name: "GridfinityRebuiltTests",
            dependencies: ["GridfinityRebuilt", "GridfinityTestSupport", "Cadova"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ]
)
