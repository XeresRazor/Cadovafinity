// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "GridfinityCustomizers",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GridfinityModels", targets: ["GridfinityModels"]),
        .executable(name: "gridfinity-baseplate", targets: ["gridfinity-baseplate"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tomasf/Cadova.git", from: "1.3.0"),
        .package(path: "../GridfinityRebuilt"),
    ],
    targets: [
        .target(
            name: "GridfinityModels",
            dependencies: [
                "Cadova",
                .product(name: "GridfinityRebuilt", package: "GridfinityRebuilt"),
            ],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .executableTarget(
            name: "gridfinity-baseplate",
            dependencies: ["GridfinityModels", "Cadova"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .testTarget(
            name: "GridfinityModelsTests",
            dependencies: [
                "GridfinityModels", "Cadova",
                .product(name: "GridfinityRebuilt", package: "GridfinityRebuilt"),
                .product(name: "GridfinityTestSupport", package: "GridfinityRebuilt"),
            ],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ]
)
