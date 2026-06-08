import Foundation

enum TranscriptionQualityService {
    static let minimumRecordingDuration: TimeInterval = 0.3

    /// Bekannte Whisper-Halluzinationen, die bei Stille (meist am Ende) angehängt werden.
    /// Längere Varianten zuerst, damit sie vor kürzeren greifen.
    private static let trailingHallucinationPhrases: [String] = [
        "Vielen Dank für's Zuschauen.",
        "Vielen Dank fürs Zuschauen.",
        "Danke für's Zuschauen.",
        "Danke fürs Zuschauen.",
        "Untertitel der Amara.org-Community",
        "Untertitelung des ZDF, 2020",
        "Untertitel im Auftrag des ZDF",
        "Bis zum nächsten Mal.",
        "Vielen Dank.",
        "Vielen Dank",
        "Tschüss.",
        "Thanks for watching.",
        "Thank you for watching.",
        "Thank you.",
    ]

    private static let trailingPunctuation = CharacterSet(charactersIn: " .,!?…\n\t\"'»«")

    static func shouldRejectRecording(duration: TimeInterval) -> Bool {
        duration < minimumRecordingDuration
    }

    static func cleanedTranscript(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Reinigung für den rohen Whisper-Text: trimmt und entfernt typische
    /// Whisper-Halluzinationen am Ende (z.B. "Vielen Dank."). Wird NUR auf den
    /// Transkriptionstext angewendet, nicht auf das LLM-Ergebnis.
    static func cleanedRawTranscript(_ text: String) -> String {
        removingTrailingHallucinations(cleanedTranscript(text))
    }

    private static func removingTrailingHallucinations(_ input: String) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)

        var changed = true
        while changed {
            changed = false

            // Endständige Satzzeichen/Leerzeichen für den Vergleich abschneiden.
            let core = trimmingTrailing(text, in: trailingPunctuation)

            for phrase in trailingHallucinationPhrases {
                let needle = trimmingTrailing(phrase, in: trailingPunctuation)
                guard !needle.isEmpty, core.lowercased().hasSuffix(needle.lowercased()) else { continue }

                let cutIndex = core.index(core.endIndex, offsetBy: -needle.count)

                // Steht die Phrase ganz alleine? Dann nicht entfernen (könnte echte kurze Aussage sein).
                guard cutIndex > core.startIndex else { break }

                // Nur an einer Wortgrenze schneiden (Leerzeichen oder Satzzeichen davor).
                let before = core[core.index(before: cutIndex)]
                if before.isWhitespace || ".,!?…\"'»«-–".contains(before) {
                    text = trimmingTrailing(String(core[core.startIndex..<cutIndex]), in: trailingPunctuation)
                    changed = true
                    break
                }
            }
        }

        return text
    }

    private static func trimmingTrailing(_ string: String, in set: CharacterSet) -> String {
        var result = string
        while let last = result.unicodeScalars.last, set.contains(last) {
            result.unicodeScalars.removeLast()
        }
        return result
    }

    static func isLikelyArtifact(_ text: String, recordingDuration: TimeInterval) -> Bool {
        let cleaned = cleanedTranscript(text)
        guard !cleaned.isEmpty else { return true }

        let words = cleaned.split { $0.isWhitespace || $0.isNewline }
        let letters = cleaned.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count

        if letters == 0 {
            return true
        }

        if recordingDuration < 0.55 && (words.count >= 5 || cleaned.count >= 32) {
            return true
        }

        if recordingDuration < 0.8 && cleaned.count >= 56 {
            return true
        }

        return false
    }
}
