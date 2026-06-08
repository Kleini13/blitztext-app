import Cocoa
import Observation

// HotkeyMode lebt in WorkflowProtocol.swift (plattformneutral, von AppSettings genutzt).

enum HotkeyEvent {
    case down(WorkflowType)  // Keys pressed
    case up(WorkflowType)    // Keys released (for hold mode)
    case cancel              // Escape pressed
}

// HotkeyCombo lebt in WorkflowProtocol.swift (plattformneutral, von AppSettings genutzt).

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
