import Foundation

/// Protocol for audio capture implementations
protocol AudioCaptureProvider {
    /// Sample rate of captured audio
    var sampleRate: Double { get }

    /// Number of audio channels
    var channelCount: Int { get }

    /// Whether capture is currently active
    var isCapturing: Bool { get }

    /// Human-readable name of the capture method
    var captureMethodName: String { get }

    /// Start capturing audio
    /// - Parameter onAudioData: Callback that receives PCM16 audio data
    /// - Parameter onCaptureStopped: Optional callback when capture is stopped externally (by system)
    func startCapture(onAudioData: @escaping (Data) -> Void, onCaptureStopped: (() -> Void)?) async throws

    /// Stop capturing audio
    func stopCapture() async
}
