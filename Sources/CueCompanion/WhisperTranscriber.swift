import Foundation
import WhisperKit

/// Word-level transcription result
struct TranscriptWord: Codable {
    let word: String
    let start: Double  // seconds
    let end: Double    // seconds
}

/// Transcription result with word-level timestamps
struct TranscriptionResult: Codable {
    let text: String
    let words: [TranscriptWord]
    let language: String
    let duration: Double  // audio duration in seconds
}

/// Error types for transcription
enum TranscriberError: Error, LocalizedError {
    case modelNotLoaded
    case transcriptionFailed(String)
    case invalidAudioData
    case modelDownloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model not loaded"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .invalidAudioData:
            return "Invalid audio data"
        case .modelDownloadFailed(let message):
            return "Model download failed: \(message)"
        }
    }
}

/// Local transcription service using WhisperKit
actor WhisperTranscriber {
    private var whisperKit: WhisperKit?
    private var isLoading = false
    private let modelName: String

    /// Model status for UI
    enum ModelStatus: Codable {
        case notLoaded
        case loading(progress: Double)
        case ready
        case error(String)
    }

    private(set) var status: ModelStatus = .notLoaded

    init(modelName: String = "openai_whisper-medium") {
        self.modelName = modelName
    }

    /// Load the Whisper model (downloads if not cached)
    func loadModel(progressHandler: ((Double) -> Void)? = nil) async throws {
        guard !isLoading else { return }

        if whisperKit != nil {
            status = .ready
            return
        }

        isLoading = true
        status = .loading(progress: 0)

        do {
            print("Loading WhisperKit model: \(modelName)")

            // WhisperKit automatically downloads and caches models
            let config = WhisperKitConfig(
                model: modelName,
                verbose: true,
                logLevel: .debug,
                prewarm: true,
                load: true
            )

            whisperKit = try await WhisperKit(config)

            status = .ready
            isLoading = false
            print("WhisperKit model loaded successfully")
        } catch {
            status = .error(error.localizedDescription)
            isLoading = false
            throw TranscriberError.modelDownloadFailed(error.localizedDescription)
        }
    }

    /// Check if model is ready
    var isReady: Bool {
        whisperKit != nil
    }

    /// Transcribe audio data with word-level timestamps
    /// - Parameter audioData: Audio data (WAV, MP3, or raw PCM)
    /// - Returns: Transcription result with word timestamps
    func transcribe(audioData: Data) async throws -> TranscriptionResult {
        guard whisperKit != nil else {
            throw TranscriberError.modelNotLoaded
        }

        guard !audioData.isEmpty else {
            throw TranscriberError.invalidAudioData
        }

        // Detect audio format and save to temp file
        // WhisperKit's file-based transcription handles format conversion automatically
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("cue_audio_\(UUID().uuidString).wav")

        do {
            try audioData.write(to: tempFile)
            print("Saved audio to temp file: \(tempFile.path), size: \(audioData.count) bytes")

            // Use file-based transcription which handles WAV headers properly
            let result = try await transcribe(filePath: tempFile.path)

            // Clean up temp file
            try? FileManager.default.removeItem(at: tempFile)

            return result
        } catch let error as TranscriberError {
            try? FileManager.default.removeItem(at: tempFile)
            throw error
        } catch {
            try? FileManager.default.removeItem(at: tempFile)
            throw TranscriberError.transcriptionFailed(error.localizedDescription)
        }
    }

    /// Transcribe audio file with word-level timestamps
    /// - Parameter filePath: Path to audio file (WAV, MP3, etc.)
    /// - Returns: Transcription result with word timestamps
    func transcribe(filePath: String) async throws -> TranscriptionResult {
        guard let whisper = whisperKit else {
            throw TranscriberError.modelNotLoaded
        }

        print("Transcribing file: \(filePath)")

        do {
            let results = try await whisper.transcribe(
                audioPath: filePath,
                decodeOptions: DecodingOptions(
                    verbose: false,
                    task: .transcribe,
                    wordTimestamps: true
                )
            )

            guard let result = results.first else {
                throw TranscriberError.transcriptionFailed("No transcription result")
            }

            var words: [TranscriptWord] = []

            for segment in result.segments {
                if let segmentWords = segment.words {
                    for word in segmentWords {
                        words.append(TranscriptWord(
                            word: word.word,
                            start: Double(word.start),
                            end: Double(word.end)
                        ))
                    }
                }
            }

            // Get audio duration from file
            let duration = try await getAudioDuration(filePath: filePath)

            return TranscriptionResult(
                text: result.text,
                words: words,
                language: result.language,
                duration: duration
            )
        } catch let error as TranscriberError {
            throw error
        } catch {
            throw TranscriberError.transcriptionFailed(error.localizedDescription)
        }
    }

    /// Get audio duration from file
    private func getAudioDuration(filePath: String) async throws -> Double {
        let url = URL(fileURLWithPath: filePath)
        let asset = AVURLAsset(url: url)

        do {
            let duration = try await asset.load(.duration)
            return CMTimeGetSeconds(duration)
        } catch {
            return 0
        }
    }
}

// MARK: - AVFoundation import for duration
import AVFoundation
