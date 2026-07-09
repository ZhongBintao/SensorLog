import SwiftUI

struct AppView: View {
    @State private var selectedTab: AppTab = .sensors

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    tab.makeContentView()
                }
                .tabItem { tab.label }
                .tag(tab)
            }
        }
    }
}

#Preview {
    AppView()
        .environment(SensorManager.preview)
        .modelContainer(for: SensorSnapshot.self, inMemory: true)
}
