import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(SensorManager.self) private var sensorManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.system.rawValue
    @Query private var snapshots: [SensorSnapshot]

    @State private var isConfirmingClear = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Appearance") {
                LocalizedReadingRow("Mode", valueKey: "Follow System", fallbackStatus: .available)
                LocalizedReadingRow("Current Appearance", valueKey: currentSystemAppearanceKey, fallbackStatus: .available)
            }

            Section("Language") {
                Picker("Language", selection: $appLanguageRawValue) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(LocalizedStringKey(language.titleKey))
                            .tag(language.rawValue)
                    }
                }
            }

            Section {
                PermissionRow(
                    titleKey: "Location",
                    valueKey: sensorManager.permissions.location.titleKey,
                    systemImage: "location",
                    tint: locationTint
                )
                PermissionRow(
                    titleKey: "Motion & Fitness",
                    valueKey: sensorManager.permissions.motion.titleKey,
                    systemImage: "figure.walk",
                    tint: motionTint
                )

                Button {
                    openAppSettings()
                } label: {
                    Label("Open App Settings", systemImage: "gearshape")
                }
            } header: {
                Text("Permissions")
            } footer: {
                Text("Motion access is updated after iOS grants or limits Motion & Fitness data.")
            }

            Section {
                CapabilityRow(titleKey: "Device Motion", isAvailable: sensorManager.availability.deviceMotion)
                CapabilityRow(titleKey: "Gyroscope", isAvailable: sensorManager.availability.gyroscope)
                CapabilityRow(titleKey: "Accelerometer", isAvailable: sensorManager.availability.accelerometer)
                CapabilityRow(titleKey: "Barometer / Altimeter", isAvailable: sensorManager.availability.barometer)
                CapabilityRow(titleKey: "Pedometer", isAvailable: sensorManager.availability.pedometer)
                CapabilityRow(titleKey: "Activity Recognition", isAvailable: sensorManager.availability.activityRecognition)
            } header: {
                Text("Sensor Support")
            } footer: {
                Text("Support depends on the iPhone model, iOS permissions, and system availability.")
            }

            Section("Data Management") {
                HStack {
                    Label("Snapshot Count", systemImage: "number")
                    Spacer()
                    Text("\(snapshots.count)")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Button(role: .destructive) {
                    isConfirmingClear = true
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
                .disabled(snapshots.isEmpty)
            }

            Section("App Information") {
                ReadingRow("App Name", value: "SensorLog", fallbackStatus: .available)
                ReadingRow("Version", value: versionString, fallbackStatus: .available)
                LocalizedReadingRow("Data Policy", valueKey: "On-device storage only. No upload, no server, no third-party SDK.", fallbackStatus: .available)
                LocalizedReadingRow("Device Note", valueKey: "Sensor readings depend on device hardware, permissions, and current system state.", fallbackStatus: .available)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .task {
            sensorManager.start()
        }
        .alert("Clear All Snapshots?", isPresented: $isConfirmingClear) {
            Button("Cancel", role: .cancel) { }
            Button("Clear History", role: .destructive) {
                clearAll()
            }
        } message: {
            Text("This removes all local snapshots from this device.")
        }
        .alert("Settings Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var locationTint: Color {
        switch sensorManager.permissions.location {
        case .authorizedWhenInUse:
            .teal
        case .notDetermined:
            .orange
        case .denied, .restricted:
            .red
        }
    }

    private var motionTint: Color {
        switch sensorManager.permissions.motion {
        case .available:
            .teal
        case .unknown:
            .orange
        case .deniedRestricted:
            .red
        }
    }

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var currentSystemAppearanceKey: String {
        switch colorScheme {
        case .dark:
            "Dark"
        case .light:
            "Light"
        @unknown default:
            "Follow System"
        }
    }

    private func clearAll() {
        for snapshot in snapshots {
            modelContext.delete(snapshot)
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(SensorManager.preview)
            .modelContainer(for: SensorSnapshot.self, inMemory: true)
    }
}
