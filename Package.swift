// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeNotch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ClaudeNotch", path: "Sources/ClaudeNotch")
    ]
)
