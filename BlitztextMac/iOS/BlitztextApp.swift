import SwiftUI

@main
struct BlitztextApp: App {
    @State private var store = BlitztextStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .onAppear {
                    AudioRecorder.requestMicrophonePermission()
                }
        }
    }
}
