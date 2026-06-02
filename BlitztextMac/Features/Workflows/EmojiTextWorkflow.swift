import Foundation
import AppKit
import Observation

@Observable
@MainActor
final class EmojiTextWorkflow: Workflow {
    let type = WorkflowType.emojiText
    var phase: WorkflowPhase = .idle {
        didSet { onPhaseChange?(phase) }
    }
    var onOutput: WorkflowOutputHandler?
    var onPhaseChange: WorkflowPhaseChangeHandler?

    private let recorder = AudioRecorder()
    private let settings: EmojiTextSettings
    private let customTerms: [String]
    private let language: String
    private let backend: TranscriptionBackend
    private let localModelName: String
    private var processingTask: Task<Void, Never>?

    init(
        settings: EmojiTextSettings,
        customTerms: [String] = [],
        language: String = "de",
        backend: TranscriptionBackend = .remote,
        localModelName: String = LocalTranscriptionService.recommendedFastModelName
    ) {
        self.settings = settings
        self.customTerms = customTerms
        self.language = language
        self.backend = backend
        self.localModelName = localModelName
    }

    // MARK: - Recording State

    var isRecording: Bool { recorder.isRecording }
    var audioLevel: Float { recorder.audioLevel }

    // MARK: - Workflow Protocol

    func start() {
        phase = .running("Aufnahme l\u{00E4}uft ...")
        recorder.startRecording()

        if let error = recorder.errorMessage {
            phase = .error(error)
        }
    }

    func stop() {
        if recorder.isRecording {
            recorder.stopRecording()
            guard !TranscriptionQualityService.shouldRejectRecording(duration: recorder.lastRecordingDuration) else {
                recorder.discardRecording()
                phase = .error("Keine Aufnahme erkannt.")
                return
            }
            processRecording()
        } else {
            processingTask?.cancel()
            phase = .idle
        }
    }

    func reset() {
        processingTask?.cancel()
        if recorder.isRecording {
            recorder.stopRecording()
        }
        recorder.discardRecording()
        phase = .idle
    }

    // MARK: - Two-Phase Processing: Transkription -> Emoji

    private func processRecording() {
        guard let url = recorder.recordingURL else {
            phase = .error("Keine Aufnahme vorhanden.")
            return
        }

        phase = .running(backend == .local ? "Wird lokal transkribiert ..." : "Wird transkribiert ...")
        let recordingDuration = recorder.lastRecordingDuration
        let vocabularyHints = recordingDuration >= 0.9 ? customTerms : []

        processingTask = Task {
            defer {
                try? FileManager.default.removeItem(at: url)
            }

            do {
                // Phase 1: Transkription (lokal via WhisperKit oder remote via OpenAI)
                let rawText = try await TranscriptionService.transcribe(
                    audioURL: url,
                    backend: backend,
                    customTerms: vocabularyHints,
                    language: language,
                    localModelName: localModelName
                )
                let cleanedRawText = TranscriptionQualityService.cleanedTranscript(rawText)
                guard !TranscriptionQualityService.isLikelyArtifact(cleanedRawText, recordingDuration: recordingDuration) else {
                    phase = .error("Keine Aufnahme erkannt.")
                    return
                }

                if Task.isCancelled { return }

                // Phase 2: Add emojis
                phase = .running("Emojis werden eingef\u{00FC}gt ...")

                let result = try await LLMService.addEmojis(
                    text: cleanedRawText,
                    settings: settings
                )
                let cleanedResult = TranscriptionQualityService.cleanedTranscript(result)
                phase = .done(cleanedResult)
                onOutput?(cleanedResult)
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }
}
