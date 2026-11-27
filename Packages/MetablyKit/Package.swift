// swift-tools-version: 6.2
import PackageDescription

// MetablyKit holds every layer of the app except the thin app shell.
// Dependency direction is strictly one way:
//   MetablyFeatures -> MetablyPersistence, MetablySyntheticData, MetablyDomain
//   MetablyPersistence -> MetablyDomain
//   MetablyHealthKit -> MetablyDomain
//   MetablyDomain -> Foundation only
let package = Package(
    name: "MetablyKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26),
        // macOS is listed only so `swift test` can run the package on a Mac or CI runner.
        .macOS(.v26),
    ],
    products: [
        .library(name: "MetablyDomain", targets: ["MetablyDomain"]),
        .library(name: "MetablyPersistence", targets: ["MetablyPersistence"]),
        .library(name: "MetablyHealthKit", targets: ["MetablyHealthKit"]),
        .library(name: "MetablySyntheticData", targets: ["MetablySyntheticData"]),
        .library(name: "MetablyFeatures", targets: ["MetablyFeatures"]),
    ],
    targets: [
        .target(name: "MetablyDomain"),
        .target(name: "MetablyPersistence", dependencies: ["MetablyDomain"]),
        .target(name: "MetablyHealthKit", dependencies: ["MetablyDomain"]),
        .target(name: "MetablySyntheticData", dependencies: ["MetablyDomain"]),
        .target(
            name: "MetablyFeatures",
            dependencies: ["MetablyDomain", "MetablyPersistence", "MetablySyntheticData"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "MetablyDomainTests", dependencies: ["MetablyDomain"]),
        .testTarget(name: "MetablyPersistenceTests", dependencies: ["MetablyPersistence", "MetablyDomain"]),
        .testTarget(name: "MetablySyntheticDataTests", dependencies: ["MetablySyntheticData", "MetablyDomain"]),
        .testTarget(name: "MetablyFeaturesTests", dependencies: ["MetablyFeatures", "MetablyDomain"]),
    ]
)
