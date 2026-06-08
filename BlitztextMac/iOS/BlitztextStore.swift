import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class BlitztextStore {
    // UI-Zustand
    var selectedType: WorkflowType = .transcription
    var resultText: String = ""
    var statusText: String = ""
    var errorText: String?
    var isRecording = false
    var isProcessing = false

    // Einstellungen (persistiert)
    var targetLanguage: TranslationLanguage {
        didSet { defaults.set(targetLanguage.rawValue, forKey: Keys.targetLanguage) }
    }

    private var activeWorkflow: (any Workflow)?
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let targetLanguage = "ios.targetLanguage"
    }

    init() {
        targetLanguage = TranslationLanguage(rawValue: defaults.string(forKey: Keys.targetLanguage) ?? "") ?? .english
    }

    // MARK: - Keys / Verfügbarkeit

    var hasAnthropicKey: Bool { KeychainService.load(key: .anthropicAPIKey) != nil }
    var hasOpenAIKey: Bool { KeychainService.load(key: .openAIAPIKey) != nil }

    /// Reiner Transkriptions-Modus braucht kein Claude.
    private func needsAnthropic(_ type: WorkflowType) -> Bool {
        switch type {
        case .transcription, .localTranscription: return false
        default: return true
        }
    }

    func canRun(_ type: WorkflowType) -> Bool {
        if needsAnthropic(type) {
            return hasOpenAIKey && hasAnthropicKey
        }
        return hasOpenAIKey
    }

    func blockingHint(for type: WorkflowType) -> String? {
        if !hasOpenAIKey {
            return "OpenAI API Key fehlt (für die Transkription). In den Einstellungen hinterlegen."
        }
        if needsAnthropic(type), !hasAnthropicKey {
            return "Anthropic API Key fehlt (für die KI-Aufbereitung). In den Einstellungen hinterlegen."
        }
        return nil
    }

    // MARK: - Aufnahme steuern

    func toggle() {
        if isRecording {
            isRecording = false
            isProcessing = true
            activeWorkflow?.stop()
        } else {
            start(selectedType)
        }
    }

    private func start(_ type: WorkflowType) {
        errorText = nil
        resultText = ""
        statusText = "Aufnahme läuft …"

        let workflow = makeWorkflow(type)

        workflow.onPhaseChange = { [weak self] phase in
            self?.handlePhase(phase)
        }
        workflow.onOutput = { [weak self] text in
            guard let self else { return }
            self.resultText = text
            #if canImport(UIKit)
            UIPasteboard.general.string = text
            #endif
        }

        activeWorkflow = workflow
        isRecording = true
        isProcessing = false
        workflow.start()
    }

    private func handlePhase(_ phase: WorkflowPhase) {
        switch phase {
        case .idle:
            statusText = ""
        case .running(let message):
            statusText = message
        case .done:
            isRecording = false
            isProcessing = false
            statusText = ""
        case .error(let message):
            isRecording = false
            isProcessing = false
            statusText = ""
            errorText = message
        }
    }

    private func makeWorkflow(_ type: WorkflowType) -> any Workflow {
        let language = "de"
        switch type {
        case .transcription, .localTranscription:
            return TranscriptionWorkflow(type: .transcription, language: language, backend: .remote)
        case .textImprover:
            return TextImprovementWorkflow(settings: TextImprovementSettings(), language: language, backend: .remote)
        case .dampfAblassen:
            return DampfAblassenWorkflow(settings: DampfAblassenSettings(), language: language, backend: .remote)
        case .emojiText:
            return EmojiTextWorkflow(settings: EmojiTextSettings(), language: language, backend: .remote)
        case .concept:
            return ConceptWorkflow(settings: ConceptSettings(), language: language, backend: .remote)
        case .translate:
            return TranslateWorkflow(settings: TranslateSettings(targetLanguage: targetLanguage), language: language, backend: .remote)
        }
    }

    // MARK: - API-Keys

    func saveAnthropicKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? KeychainService.save(key: .anthropicAPIKey, value: trimmed)
    }

    func saveOpenAIKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? KeychainService.save(key: .openAIAPIKey, value: trimmed)
    }
}
