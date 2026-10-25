// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CraftPrompt",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "CraftPrompt",
            targets: ["CraftPrompt"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CraftPrompt",
            dependencies: [],
            path: "Sources/CraftPrompt"
        ),
        .testTarget(
            name: "CraftPromptTests",
            dependencies: ["CraftPrompt"],
            path: "Tests/CraftPromptTests"
        )
    ]
)
