import SwiftUI

@main
struct ArrowTuneApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(state)
                .environmentObject(state.pro)
        }
    }
}
