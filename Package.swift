// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotchUs",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "NotchUs", path: "Sources/NotchUs")
    ]
)
