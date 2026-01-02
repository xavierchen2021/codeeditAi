import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
class SpeechRecognitionService: ObservableObject {
    @Published var transcribedText = ""
    @Published var partialTranscription = ""

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Recognition Control

    func startRecognition() async throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechRecognitionError.recognitionUnavailable
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        let inputNode = audioEngine.inputNode

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        self.recognitionRequest = recognitionRequest
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            throw SpeechRecognitionError.invalidAudioFormat
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, when in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            throw SpeechRecognitionError.engineStartFailed
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let transcription = result.bestTranscription.formattedString

                Task { @MainActor in
                    if result.isFinal {
                        self.transcribedText = transcription
                    } else {
                        self.partialTranscription = transcription
                    }
                }
            }

            if error != nil || result?.isFinal == true {
                audioEngine.stop()
                inputNode.removeTap(onBus: 0)
            }
        }
    }

    func stopRecognition() async -> String {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        audioEngine = nil

        // Wait for final transcription
        try? await Task.sleep(for: .milliseconds(500))

        let finalText = transcribedText.isEmpty ? partialTranscription : transcribedText
        return finalText
    }

    func cancelRecognition() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        audioEngine = nil

        transcribedText = ""
        partialTranscription = ""
    }

    func resetTranscriptions() {
        transcribedText = ""
        partialTranscription = ""
    }

    // MARK: - Errors

    enum SpeechRecognitionError: LocalizedError {
        case recognitionUnavailable
        case invalidAudioFormat
        case engineStartFailed

        var errorDescription: String? {
            switch self {
            case .recognitionUnavailable:
                return "Speech recognition is not available. Please enable Siri in System Settings > Siri & Spotlight."
            case .invalidAudioFormat:
                return "Invalid audio format detected."
            case .engineStartFailed:
                return "Failed to start audio engine."
            }
        }
    }
}
