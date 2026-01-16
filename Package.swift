// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CueCompanion",
    platforms: [
        .macOS(.v14)  // WhisperKit requires macOS 14+
    ],
    dependencies: [
        // WebSocket server
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.0.0"),
        // WhisperKit for local transcription
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "CueCompanion",
            dependencies: [
                .product(name: "WebSocketKit", package: "websocket-kit"),
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            resources: [
                // Model files will be downloaded on first use
            ]
        ),
    ]
)
