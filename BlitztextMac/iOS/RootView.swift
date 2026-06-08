import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RootView: View {
    @Bindable var store: BlitztextStore
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                modePicker

                if let hint = store.blockingHint(for: store.selectedType) {
                    Label(hint, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                }

                Spacer(minLength: 0)

                recordButton

                Text(statusLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 20)

                Spacer(minLength: 0)

                resultSection
            }
            .padding(.vertical)
            .navigationTitle("Blitztext")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(store: store)
            }
        }
    }

    private var modePicker: some View {
        Picker("Modus", selection: $store.selectedType) {
            ForEach(WorkflowType.mainMenuCases) { type in
                Label(type.displayName, systemImage: type.icon).tag(type)
            }
        }
        .pickerStyle(.menu)
        .disabled(store.isRecording || store.isProcessing)
        .padding(.horizontal)
    }

    private var recordButton: some View {
        Button {
            store.toggle()
        } label: {
            ZStack {
                Circle()
                    .fill(buttonColor.opacity(0.15))
                    .frame(width: 120, height: 120)
                if store.isProcessing {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    Image(systemName: store.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(buttonColor)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(store.isProcessing || (!store.isRecording && !store.canRun(store.selectedType)))
    }

    private var buttonColor: Color {
        store.isRecording ? .red : .accentColor
    }

    private var statusLine: String {
        if store.isProcessing { return store.statusText.isEmpty ? "Wird verarbeitet …" : store.statusText }
        if store.isRecording { return store.statusText.isEmpty ? "Aufnahme läuft …" : store.statusText }
        return store.selectedType.subtitle
    }

    @ViewBuilder
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = store.errorText {
                Label(error, systemImage: "xmark.octagon.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !store.resultText.isEmpty {
                ScrollView {
                    Text(store.resultText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 220)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 12) {
                    Button {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = store.resultText
                        #endif
                    } label: {
                        Label("Kopieren", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)

                    ShareLink(item: store.resultText) {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.horizontal)
    }
}
