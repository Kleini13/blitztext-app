import Cocoa
import Observation

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

enum HotkeyEvent {
    case down(WorkflowType)  // Keys pressed
    case up(WorkflowType)    // Keys released (for hold mode)
    case cancel              // Escape pressed
}

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
}

@Observable
@MainActor
final class HotkeyService {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var keyMonitor: Any?
    private var activeCombo: WorkflowType?  // Which combo is currently held

    /// Aktive Zuordnung Tastenkombi -> Workflow, datengetrieben aus den Einstellungen.
    private var bindings: [(type: WorkflowType, flags: NSEvent.ModifierFlags)] = []

    var onHotkeyEvent: ((HotkeyEvent) -> Void)?

    /// Übernimmt die konfigurierten Hotkeys. Doppelt vergebene Kombis werden in
    /// WorkflowType-Reihenfolge entschieden (erste gewinnt).
    func updateBindings(_ map: [WorkflowType: HotkeyCombo]) {
        var seen = Set<UInt>()
        var result: [(type: WorkflowType, flags: NSEvent.ModifierFlags)] = []
        for type in WorkflowType.allCases {
            guard let combo = map[type], let flags = combo.flags else { continue }
            guard !seen.contains(flags.rawValue) else { continue }
            seen.insert(flags.rawValue)
            result.append((type, flags))
        }
        bindings = result
    }

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlags(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlags(event)
            }
            return event
        }
        // Escape key monitor for toggle mode
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                if event.keyCode == 53 { // Escape
                    self?.handleEscape()
                }
            }
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        globalMonitor = nil
        localMonitor = nil
        keyMonitor = nil
    }

    private func handleFlags(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Exakte Übereinstimmung mit einer konfigurierten Kombi -> down
        if let match = bindings.first(where: { $0.flags == flags }) {
            if activeCombo == nil {
                activeCombo = match.type
                onHotkeyEvent?(.down(match.type))
            }
            return
        }

        // Keine passende Kombi mehr (Tasten losgelassen) -> up
        if let combo = activeCombo {
            activeCombo = nil
            onHotkeyEvent?(.up(combo))
        }
    }

    private func handleEscape() {
        activeCombo = nil
        onHotkeyEvent?(.cancel)
    }
}
