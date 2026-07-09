import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(SensorManager.self) private var sensorManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var snapshots: [SensorSnapshot]

    @State private var isConfirmingClear = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Appearance") {
                ReadingRow("Mode", value: String(localized: "Follow System"), fallbackStatus: .available)
                ReadingRow("Current System Appearance", value: currentSystemAppearance, fallbackStatus: .available)
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
                Text("iOS does not expose every Motion & Fitness permission state with the same precision as Location.")
            }

            Section {
                CapabilityRow(titleKey: "Device Motion", isAvailable: sensorManager.availability.deviceMotion)
                CapabilityRow(titleKey: "Gyroscope", isAvailable: sensorManager.availability.gyroscope)
                CapabilityRow(titleKey: "Accelerometer", isAvailable: sensorManager.availability.accelerometer)
                CapabilityRow(titleKey: "Barometer / Altimeter", isAvailable: sensorManager.availability.barometer)
                CapabilityRow(titleKey: "Pedometer", isAvailable: sensorManager.availability.pedometer)
                CapabilityRow(titleKey: "Activity Recognition", isAvailable: sensorManager.availability.activityRecognition)
            } header: {
                Text("Device Capabilities")
            } footer: {
                Text("Simulator results do not prove real device sensor availability or accuracy.")
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
                ReadingRow("Data Policy", value: String(localized: "Local device only. No upload, no server, no third-party SDK."), fallbackStatus: .available)
                ReadingRow("Self-Test Note", value: String(localized: "Use a real iPhone for actual sensor capability and accuracy checks."), fallbackStatus: .available)
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

    private var currentSystemAppearance: String {
        switch colorScheme {
        case .dark:
            String(localized: "Dark")
        case .light:
            String(localized: "Light")
        @unknown default:
            String(localized: "Follow System")
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
