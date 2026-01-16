import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia

/// Simple file logger for debugging
func logToFile(_ message: String) {
    let logPath = "/tmp/cue_companion_debug.log"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logMessage = "[\(timestamp)] \(message)\n"

    if let data = logMessage.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logPath) {
            if let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: logPath, contents: data)
        }
    }
}

/// Callback for audio data
typealias AudioDataCallback = (Data) -> Void

/// Captures system audio using ScreenCaptureKit
/// Requires Screen Recording permission
class AudioCapture: NSObject, AudioCaptureProvider {
    private var stream: SCStream?
    private var _isCapturing = false
    private var onAudioData: AudioDataCallback?

    let sampleRate: Double = 24000  // OpenAI Realtime API expects 24kHz
    let channelCount: Int = 1       // Mono
    let captureMethodName = "ScreenCaptureKit"

    var isCapturing: Bool { _isCapturing }

    /// Start capturing system audio
    func startCapture(onAudioData: @escaping AudioDataCallback) async throws {
        self.onAudioData = onAudioData
        logToFile("Starting audio capture...")

        // Get available content to capture
        let availableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        logToFile("Got available content: \(availableContent.displays.count) displays")

        // Create a filter to capture all audio (no specific window/app filter)
        // We use the entire display to capture all system audio
        guard let display = availableContent.displays.first else {
            throw AudioCaptureError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Configure stream for audio only
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = Int(sampleRate)
        config.channelCount = channelCount

        // Minimize video capture since we only need audio
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)  // 1 FPS minimum

        // Create and start the stream
        stream = SCStream(filter: filter, configuration: config, delegate: nil)

        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))

        try await stream?.startCapture()
        _isCapturing = true

        logToFile("ScreenCaptureKit audio capture started (sample rate: \(sampleRate)Hz, channels: \(channelCount))")
        print("ScreenCaptureKit audio capture started (sample rate: \(sampleRate)Hz, channels: \(channelCount))")
    }

    /// Stop capturing
    func stopCapture() async {
        guard _isCapturing, let stream = stream else { return }

        do {
            try await stream.stopCapture()
            print("ScreenCaptureKit audio capture stopped")
        } catch {
            print("Error stopping capture: \(error)")
        }

        self.stream = nil
        _isCapturing = false
    }
}

// MARK: - SCStreamOutput
extension AudioCapture: SCStreamOutput {
    private static var audioChunkCount = 0

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Log all types received
        if AudioCapture.audioChunkCount == 0 {
            logToFile("First sample buffer received, type: \(type == .audio ? "audio" : "video")")
        }

        guard type == .audio else { return }

        // Convert CMSampleBuffer to PCM16 data
        guard let data = convertToPCM16(sampleBuffer: sampleBuffer) else {
            logToFile("⚠️ Failed to convert sample buffer to PCM16")
            print("⚠️ Failed to convert sample buffer to PCM16")
            return
        }

        // Debug: print every 100 chunks
        AudioCapture.audioChunkCount += 1
        if AudioCapture.audioChunkCount % 100 == 1 {
            logToFile("🔊 Audio chunk #\(AudioCapture.audioChunkCount), size=\(data.count) bytes")
            print("🔊 Audio chunk #\(AudioCapture.audioChunkCount), size=\(data.count) bytes")
        }

        // Send to callback
        onAudioData?(data)
    }

    /// Convert CMSampleBuffer to PCM16 Data (format expected by OpenAI Realtime API)
    private func convertToPCM16(sampleBuffer: CMSampleBuffer) -> Data? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )

        guard status == kCMBlockBufferNoErr, let pointer = dataPointer else { return nil }

        // Get format description to understand the audio format
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else {
            return nil
        }

        // ScreenCaptureKit typically outputs Float32
        if asbd.pointee.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
            // Convert Float32 to Int16 (PCM16)
            let floatCount = length / MemoryLayout<Float32>.size
            let floatPointer = UnsafeRawPointer(pointer).bindMemory(to: Float32.self, capacity: floatCount)

            var pcm16Data = Data(capacity: floatCount * MemoryLayout<Int16>.size)

            for i in 0..<floatCount {
                let sample = floatPointer[i]
                // Clamp and convert to Int16
                let clamped = max(-1.0, min(1.0, sample))
                let int16Sample = Int16(clamped * Float32(Int16.max))
                withUnsafeBytes(of: int16Sample.littleEndian) { pcm16Data.append(contentsOf: $0) }
            }

            return pcm16Data
        } else {
            // Already in integer format, return as-is
            return Data(bytes: pointer, count: length)
        }
    }
}

// MARK: - Errors
enum AudioCaptureError: Error, LocalizedError {
    case noDisplayFound
    case captureNotStarted

    var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            return "No display found for audio capture"
        case .captureNotStarted:
            return "Audio capture has not been started"
        }
    }
}
