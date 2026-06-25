import Foundation
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Hotkey Mode

enum HotkeyMode: String, Codable, CaseIterable, Identifiable {
    case hold    // Tasten halten = aufnehmen, loslassen = stoppen
    case toggle  // Einmal drücken = starten, nochmal/Escape = stoppen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hold: return "Halten"
        case .toggle: return "Drücken"
        }
    }

    var description: String {
        switch self {
        case .hold: return "Tasten halten zum Aufnehmen, loslassen zum Stoppen"
        case .toggle: return "Einmal drücken zum Starten, nochmal oder Escape zum Stoppen"
        }
    }
}

// MARK: - Hotkey Combo (plattformneutral; flags nur auf macOS)

/// Zuweisbare Tastenkombinationen (alle fn-basiert, da die Erkennung über Modifier-Flags läuft).
enum HotkeyCombo: String, Codable, CaseIterable, Identifiable {
    case none
    case fnShift, fnControl, fnOption, fnCommand
    case fnShiftControl, fnShiftOption, fnShiftCommand
    case fnControlOption, fnControlCommand, fnOptionCommand

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Kein Hotkey"
        case .fnShift: return "fn + Shift"
        case .fnControl: return "fn + Control"
        case .fnOption: return "fn + Option"
        case .fnCommand: return "fn + Command"
        case .fnShiftControl: return "fn + Shift + Control"
        case .fnShiftOption: return "fn + Shift + Option"
        case .fnShiftCommand: return "fn + Shift + Command"
        case .fnControlOption: return "fn + Control + Option"
        case .fnControlCommand: return "fn + Control + Command"
        case .fnOptionCommand: return "fn + Option + Command"
        }
    }

    /// Kompakte Anzeige fürs Menü.
    var shortLabel: String {
        displayName.replacingOccurrences(of: "Control", with: "Ctrl")
            .replacingOccurrences(of: "Option", with: "Opt")
            .replacingOccurrences(of: "Command", with: "Cmd")
    }

    #if canImport(AppKit)
    var flags: NSEvent.ModifierFlags? {
        switch self {
        case .none: return nil
        case .fnShift: return [.function, .shift]
        case .fnControl: return [.function, .control]
        case .fnOption: return [.function, .option]
        case .fnCommand: return [.function, .command]
        case .fnShiftControl: return [.function, .shift, .control]
        case .fnShiftOption: return [.function, .shift, .option]
        case .fnShiftCommand: return [.function, .shift, .command]
        case .fnControlOption: return [.function, .control, .option]
        case .fnControlCommand: return [.function, .control, .command]
        case .fnOptionCommand: return [.function, .option, .command]
        }
    }
    #endif
}

// MARK: - Workflow Types

enum WorkflowType: String, CaseIterable, Identifiable, Codable {
    case transcription
    case localTranscription
    case textImprover
    case dampfAblassen
    case emojiText
    case concept
    case translate

    var id: String { rawValue }

    static var mainMenuCases: [WorkflowType] {
        allCases.filter { $0 != .localTranscription }
    }

    var displayName: String {
        switch self {
        case .transcription: return "Blitztext"
        case .localTranscription: return "Blitztext Lokal"
        case .textImprover: return "Blitztext+"
        case .dampfAblassen: return "Blitztext $%&!"
        case .emojiText: return "Blitztext :)"
        case .concept: return "Blitztext Konzept"
        case .translate: return "Blitztext Translate"
        }
    }

    var icon: String {
        switch self {
        case .transcription: return "mic.fill"
        case .localTranscription: return "lock.shield.fill"
        case .textImprover: return "text.badge.checkmark"
        case .dampfAblassen: return "flame.fill"
        case .emojiText: return "face.smiling"
        case .concept: return "list.bullet.rectangle"
        case .translate: return "globe"
        }
    }

    var subtitle: String {
        switch self {
        case .transcription: return "Sprache rein. Text raus."
        case .localTranscription: return "Nur lokal. Kein Server."
        case .textImprover: return "Geschrieben sprechen."
        case .dampfAblassen: return "Frust rein. Entspannt raus."
        case .emojiText: return "Text rein. Emojis dazu."
        case .concept: return "Sprich frei. Konzept raus."
        case .translate: return "Sprich. Übersetzt raus."
        }
    }

    var hotkeyLabel: String {
        switch self {
        case .transcription: return "fn + Shift"
        case .localTranscription: return "fn + Shift + Ctrl"
        case .textImprover: return "fn + Control"
        case .dampfAblassen: return "fn + Option"
        case .emojiText: return "fn + Cmd"
        case .concept: return "fn + Ctrl + Opt"
        case .translate: return "fn + Ctrl + Cmd"
        }
    }

    var accentColor: String {
        switch self {
        case .transcription: return "blue"
        case .localTranscription: return "green"
        case .textImprover: return "purple"
        case .dampfAblassen: return "orange"
        case .emojiText: return "cyan"
        case .concept: return "teal"
        case .translate: return "indigo"
        }
    }
}

// MARK: - Workflow State

enum WorkflowPhase: Equatable {
    case idle
    case running(String)
    case done(String)
    case error(String)

    var isActive: Bool {
        switch self {
        case .idle: return false
        default: return true
        }
    }
}

enum WorkflowLaunchSource: Equatable {
    case manual
    case hotkeyBackground

    var presentsWorkflowPage: Bool {
        switch self {
        case .manual:
            return true
        case .hotkeyBackground:
            return false
        }
    }
}

typealias WorkflowOutputHandler = @MainActor (String) -> Void
typealias WorkflowPhaseChangeHandler = @MainActor (WorkflowPhase) -> Void

// MARK: - Workflow Protocol

@MainActor
protocol Workflow: AnyObject, Observable {
    var type: WorkflowType { get }
    var phase: WorkflowPhase { get set }
    var isRecording: Bool { get }
    var onOutput: WorkflowOutputHandler? { get set }
    var onPhaseChange: WorkflowPhaseChangeHandler? { get set }

    func start()
    func stop()
    func reset()
}

// MARK: - App Settings

struct AppSettings: Codable {
    var hotkeyMode: HotkeyMode = .hold
    var hasSeenOnboarding: Bool = false
    var secureLocalModeEnabled: Bool = false
    var selectedLocalTranscriptionModelName: String = ""
    var hasAutoSelectedFastLocalModel: Bool = false
    /// Pro Workflow (rawValue) eine zugewiesene Tastenkombi.
    var hotkeyBindings: [String: HotkeyCombo] = AppSettings.defaultHotkeyBindings
    /// Deutsche Schreibweise für alle KI-Textausgaben (Standard mit ß / Schweiz mit ss).
    var germanSpelling: GermanSpelling = .standard

    static let defaultHotkeyBindings: [String: HotkeyCombo] = [
        WorkflowType.transcription.rawValue: .fnShift,
        WorkflowType.localTranscription.rawValue: .fnShiftControl,
        WorkflowType.textImprover.rawValue: .fnControl,
        WorkflowType.dampfAblassen.rawValue: .fnOption,
        WorkflowType.emojiText.rawValue: .fnCommand,
        WorkflowType.concept.rawValue: .fnControlOption,
        WorkflowType.translate.rawValue: .fnControlCommand,
    ]

    /// Konfigurierte Kombi für einen Workflow (oder Default, sonst keine).
    func combo(for type: WorkflowType) -> HotkeyCombo {
        hotkeyBindings[type.rawValue] ?? AppSettings.defaultHotkeyBindings[type.rawValue] ?? .none
    }

    init(
        hotkeyMode: HotkeyMode = .hold,
        hasSeenOnboarding: Bool = false,
        secureLocalModeEnabled: Bool = false,
        selectedLocalTranscriptionModelName: String = "",
        hasAutoSelectedFastLocalModel: Bool = false,
        hotkeyBindings: [String: HotkeyCombo] = AppSettings.defaultHotkeyBindings,
        germanSpelling: GermanSpelling = .standard
    ) {
        self.hotkeyMode = hotkeyMode
        self.hasSeenOnboarding = hasSeenOnboarding
        self.secureLocalModeEnabled = secureLocalModeEnabled
        self.selectedLocalTranscriptionModelName = selectedLocalTranscriptionModelName
        self.hasAutoSelectedFastLocalModel = hasAutoSelectedFastLocalModel
        self.hotkeyBindings = hotkeyBindings
        self.germanSpelling = germanSpelling
    }

    enum CodingKeys: String, CodingKey {
        case hotkeyMode
        case hasSeenOnboarding
        case secureLocalModeEnabled
        case selectedLocalTranscriptionModelName
        case hasAutoSelectedFastLocalModel
        case hotkeyBindings
        case germanSpelling
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hotkeyMode = try container.decodeIfPresent(HotkeyMode.self, forKey: .hotkeyMode) ?? .hold
        hasSeenOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasSeenOnboarding) ?? false
        secureLocalModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .secureLocalModeEnabled) ?? false
        selectedLocalTranscriptionModelName = try container.decodeIfPresent(
            String.self,
            forKey: .selectedLocalTranscriptionModelName
        ) ?? ""
        hasAutoSelectedFastLocalModel = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasAutoSelectedFastLocalModel
        ) ?? false
        // Gespeicherte Zuweisungen über die Defaults legen, damit neue Workflows immer eine Default-Kombi haben.
        let stored = try container.decodeIfPresent([String: HotkeyCombo].self, forKey: .hotkeyBindings) ?? [:]
        hotkeyBindings = AppSettings.defaultHotkeyBindings.merging(stored) { _, new in new }
        germanSpelling = try container.decodeIfPresent(GermanSpelling.self, forKey: .germanSpelling) ?? .standard
    }
}

// MARK: - Deutsche Schreibweise

enum GermanSpelling: String, Codable, CaseIterable, Identifiable {
    case standard   // Deutschland/Österreich – mit ß
    case swiss      // Schweiz – ss statt ß

    var id: String { rawValue }

    /// App-weite aktuelle Einstellung, von der UI gesetzt (für KI-Modi und Transkription).
    nonisolated(unsafe) static var current: GermanSpelling = .standard

    var displayName: String {
        switch self {
        case .standard: return "Deutsch (mit ß)"
        case .swiss: return "Deutsch Schweiz (ss statt ß)"
        }
    }

    /// Zusatz für den Claude-Prompt.
    var promptInstruction: String {
        switch self {
        case .standard: return ""
        case .swiss:
            return "\n\nWichtig: Verwende durchgehend Schweizer Rechtschreibung. Schreibe niemals das Zeichen «ß», sondern immer «ss»."
        }
    }

    /// Deterministische Nachbearbeitung – garantiert kein ß in der Schweizer Variante.
    func normalized(_ text: String) -> String {
        guard self == .swiss else { return text }
        return text
            .replacingOccurrences(of: "ß", with: "ss")
            .replacingOccurrences(of: "ẞ", with: "SS")
    }
}

enum TranscriptionBackend: String, Codable {
    case remote
    case local
}

// MARK: - Workflow Settings

struct TranscriptionSettings: Codable {
    var language: String = "de"
}

struct DampfAblassenSettings: Codable {
    var systemPrompt: String = "Du erhältst ein emotional gesprochenes Transkript. Erkenne zuerst das eigentliche Ziel, Anliegen und den wahren Frust der Person. Formuliere daraus eine klare, respektvolle und wirksame Nachricht, mit der die Person ihr Ziel eher erreicht. Bewahre relevante Fakten, konkrete Probleme, Grenzen, Erwartungen und die nötige Dringlichkeit. Entferne Beleidigungen, Drohungen, Sarkasmus, Unterstellungen und unnötige Eskalation. Wenn mehrere Vorwürfe genannt werden, verdichte sie auf die entscheidenden Kernpunkte. Der Ton soll ruhig, menschlich, bestimmt und lösungsorientiert sein. Gib NUR die fertige Nachricht zurück."
    var customName: String = ""
}

struct ConceptSettings: Codable {
    /// Optionaler Zusatz-Kontext, der Claude beim Strukturieren hilft (z.B. "Projektkonzept", "Sitzungsnotiz").
    var context: String = ""
    var customName: String = ""
}

enum TranslationLanguage: String, Codable, CaseIterable, Identifiable {
    case english
    case french
    case italian
    case german
    case germanSwiss

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "Englisch"
        case .french: return "Französisch"
        case .italian: return "Italienisch"
        case .german: return "Deutsch"
        case .germanSwiss: return "Deutsch (Schweiz)"
        }
    }

    /// Name der Zielsprache für den Prompt (in der Zielsprache selbst formuliert).
    var promptName: String {
        switch self {
        case .english: return "English"
        case .french: return "French (français)"
        case .italian: return "Italian (italiano)"
        case .german: return "German (Deutsch)"
        case .germanSwiss: return "Swiss Standard German (Schweizer Hochdeutsch – verwende «ss» statt «ß»)"
        }
    }

    /// Erzwungene Schreibweise abhängig von der Zielsprache (für die Nachbearbeitung).
    var germanSpelling: GermanSpelling {
        switch self {
        case .germanSwiss: return .swiss
        default: return .standard
        }
    }
}

struct TranslateSettings: Codable {
    var targetLanguage: TranslationLanguage = .english
    var customName: String = ""
}

struct EmojiTextSettings: Codable {
    var emojiDensity: EmojiDensity = .mittel
    var customName: String = ""

    enum EmojiDensity: String, Codable, CaseIterable, Identifiable {
        case wenig
        case mittel
        case viel

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .wenig: return "Wenig"
            case .mittel: return "Mittel"
            case .viel: return "Viel"
            }
        }
    }
}

struct TextImprovementSettings: Codable {
    var systemPrompt: String = ""
    var customTerms: [String] = []
    var context: String = ""
    var tone: TextTone = .neutral
    var customName: String = ""

    enum TextTone: String, Codable, CaseIterable, Identifiable {
        case formal
        case neutral
        case casual

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .formal: return "Formell"
            case .neutral: return "Neutral"
            case .casual: return "Locker"
            }
        }
    }
}
