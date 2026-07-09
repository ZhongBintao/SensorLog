import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case sensors
    case history
    case settings

    var id: String { rawValue }

    @ViewBuilder
    func makeContentView() -> some View {
        switch self {
        case .sensors:
            SensorsView()
        case .history:
            HistoryView()
        case .settings:
            SettingsView()
        }
    }

    @ViewBuilder
    var label: some View {
        switch self {
        case .sensors:
            Label("Sensors", systemImage: "waveform.path.ecg")
        case .history:
            Label("History", systemImage: "clock.arrow.circlepath")
        case .settings:
            Label("Settings", systemImage: "gearshape")
        }
    }
}
