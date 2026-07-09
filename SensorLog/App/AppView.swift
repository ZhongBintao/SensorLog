import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .system:
            "Follow System"
        case .english:
            "English"
        case .simplifiedChinese:
            "Simplified Chinese"
        }
    }

    var locale: Locale {
        switch self {
        case .system:
            .autoupdatingCurrent
        case .english:
            Locale(identifier: "en")
        case .simplifiedChinese:
            Locale(identifier: "zh-Hans")
        }
    }
}

struct AppView: View {
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.system.rawValue
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
        .environment(\.locale, appLanguage.locale)
        .id(appLanguage.rawValue)
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .system
    }
}

#Preview {
    AppView()
        .environment(SensorManager.preview)
        .modelContainer(for: SensorSnapshot.self, inMemory: true)
}
