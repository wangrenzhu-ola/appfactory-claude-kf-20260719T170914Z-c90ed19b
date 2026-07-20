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
    }
}
