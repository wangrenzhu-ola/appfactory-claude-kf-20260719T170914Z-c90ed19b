import SwiftUI

/// Four-instrument console: Sessions, Attribution, Gear, Settings.
struct RootTabView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        TabView {
            NavigationView { SessionsListView() }
                .navigationViewStyle(.stack)
                .tabItem { Label("Sessions", systemImage: "scope") }
            NavigationView { AttributionView() }
                .navigationViewStyle(.stack)
                .tabItem { Label("Attribution", systemImage: "timeline.selection") }
            NavigationView { GearListView() }
                .navigationViewStyle(.stack)
                .tabItem { Label("Gear", systemImage: "wrench.and.screwdriver") }
            NavigationView { SettingsView() }
                .navigationViewStyle(.stack)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .accentColor(Theme.signal)
        .overlay(alignment: .top) {
            if let notice = state.lastNotice {
                StatusBar(kind: .success, text: notice)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            state.dismissNotice()
                        }
                    }
            }
        }
    }
}
