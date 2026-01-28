import Foundation

/// Manages audio capture
/// Uses ScreenCaptureKit to capture system audio
/// Note: Requires "Screen Recording" permission, but only captures audio
class AudioCaptureManager {
    private var captureProvider: AudioCaptureProvider?

    /// The capture method being used
    var captureMethodName: String {
        captureProvider?.captureMethodName ?? "None"
    }

    /// Whether capture is currently active
    var isCapturing: Bool {
        captureProvider?.isCapturing ?? false
    }

    /// Sample rate of captured audio
    var sampleRate: Double {
        captureProvider?.sampleRate ?? 24000
    }

    /// Start capturing system audio
    /// - Parameter sampleRate: Sample rate in Hz (16000 or 24000), default 24000
    /// - Parameter onAudioData: Callback that receives PCM16 audio data
    /// - Parameter onCaptureStopped: Optional callback when capture is stopped externally (by system)
    func startCapture(sampleRate: Double = 24000, onAudioData: @escaping (Data) -> Void, onCaptureStopped: (() -> Void)? = nil) async throws {
        let capture = AudioCapture()
        try await capture.startCapture(sampleRate: sampleRate, onAudioData: onAudioData, onCaptureStopped: onCaptureStopped)
        captureProvider = capture
    }

    /// Stop capturing audio
    func stopCapture() async {
        await captureProvider?.stopCapture()
        captureProvider = nil
    }
}
