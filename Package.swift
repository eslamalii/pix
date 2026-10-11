// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Pix",
    platforms: [.macOS(.v14)],
    targets: [
        // Everything about Pix but drawing: the Controller, the Routine, the Room geometry and the art contract.
        // No AppKit, no private API; this is what the tests cover.
        .target(name: "AmbientCore"),
        .executableTarget(name: "Pix", dependencies: ["AmbientCore"]),
        .testTarget(name: "AmbientCoreTests", dependencies: ["AmbientCore"]),
    ]
)
