// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Vaiven",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "VaivenCore"),
        .executableTarget(name: "Vaiven", dependencies: ["VaivenCore"]),
        .testTarget(
            name: "VaivenCoreTests",
            dependencies: ["VaivenCore"],
            swiftSettings: [
                // Con solo las Command Line Tools (sin Xcode), el plugin de Swift Testing está en una carpeta aparte.
                .unsafeFlags(["-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"])
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
