// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CueCompanion",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // WebSocket server (lightweight)
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.0.0"),
        // WhisperKit for local transcription - DISABLED to reduce app size
        // To re-enable: uncomment below and in targets, then restore WhisperTranscriber.swift
        // .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "CueCompanion",
            dependencies: [
                .product(name: "WebSocketKit", package: "websocket-kit"),
                // .product(name: "WhisperKit", package: "WhisperKit"),
            ]
        ),
    ]
)
