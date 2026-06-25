import SwiftUI

struct SettingsView: View {
    @Bindable var store: BlitztextStore
    @Environment(\.dismiss) private var dismiss

    @State private var anthropicKey = ""
    @State private var openAIKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(store.hasOpenAIKey ? "•••• (gespeichert) – neu eingeben zum Ändern" : "sk-…", text: $openAIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { saveOpenAI() }
                    Button("OpenAI Key speichern") { saveOpenAI() }
                        .disabled(openAIKey.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("OpenAI API Key")
                } footer: {
                    Text("Für die Transkription (Whisper). Audio geht an die OpenAI-API.")
                }

                Section {
                    SecureField(store.hasAnthropicKey ? "•••• (gespeichert) – neu eingeben zum Ändern" : "sk-ant-…", text: $anthropicKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { saveAnthropic() }
                    Button("Anthropic Key speichern") { saveAnthropic() }
                        .disabled(anthropicKey.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Für Umschreiben, Konzept und Übersetzen (Claude).")
                }

                Section {
                    Picker("Zielsprache", selection: $store.targetLanguage) {
                        ForEach(TranslationLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                } header: {
                    Text("Übersetzung (Blitztext Translate)")
                }

                Section {
                    Picker("Schreibweise", selection: $store.germanSpelling) {
                        ForEach(GermanSpelling.allCases) { spelling in
                            Text(spelling.displayName).tag(spelling)
                        }
                    }
                } header: {
                    Text("Deutsche Schreibweise")
                } footer: {
                    Text("Gilt für alle KI-Texte und die Transkription. Schweiz ersetzt jedes ß durch ss.")
                }

                Section {
                    Text("Lokale On-Device-Transkription (WhisperKit) ist in dieser iOS-Vorschau noch nicht aktiv. Aktuell läuft die Transkription online über OpenAI.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Hinweis")
                }
            }
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func saveAnthropic() {
        store.saveAnthropicKey(anthropicKey)
        anthropicKey = ""
    }

    private func saveOpenAI() {
        store.saveOpenAIKey(openAIKey)
        openAIKey = ""
    }
}
