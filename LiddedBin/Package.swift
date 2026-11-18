// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "LiddedBin",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LiddedBinModel", targets: ["LiddedBinModel"]),
        .executable(name: "lidded-bin", targets: ["lidded-bin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tomasf/Cadova.git", from: "1.3.0"),
        .package(path: "../GridfinityRebuilt"),
    ],
    targets: [
        .target(
            name: "LiddedBinModel",
            dependencies: [
                "Cadova",
                .product(name: "GridfinityRebuilt", package: "GridfinityRebuilt"),
            ],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .executableTarget(
            name: "lidded-bin",
            dependencies: ["LiddedBinModel", "Cadova"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .testTarget(
            name: "LiddedBinModelTests",
            dependencies: [
                "LiddedBinModel", "Cadova",
                .product(name: "GridfinityRebuilt", package: "GridfinityRebuilt"),
                .product(name: "GridfinityTestSupport", package: "GridfinityRebuilt"),
            ],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ]
)
