import SwiftData
import SwiftUI
import UIKit

struct SensorsView: View {
    @Environment(SensorManager.self) private var sensorManager
    @Environment(\.modelContext) private var modelContext
    @State private var feedback: SaveFeedback?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        StatusBadge(titleKey: "Location", status: sensorManager.liveState.locationStatus)
                        StatusBadge(titleKey: "Motion", status: sensorManager.liveState.motionStatus)
                    }

                    HStack(spacing: 8) {
                        locationPermissionAction
                        motionPermissionAction
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Live Status")
            } footer: {
                Text("Permissions are requested only when you tap a permission action or start reading the related sensor.")
            }

            Section("Location") {
                let location = sensorManager.liveState.location
                let status = sensorManager.liveState.locationStatus
                ReadingRow("Latitude", value: SensorFormatting.number(location?.latitude, digits: 6, unit: "deg"), fallbackStatus: status)
                ReadingRow("Longitude", value: SensorFormatting.number(location?.longitude, digits: 6, unit: "deg"), fallbackStatus: status)
                ReadingRow("Horizontal Accuracy", value: SensorFormatting.number(location?.horizontalAccuracy, digits: 1, unit: "m"), fallbackStatus: status)
                ReadingRow("Speed", value: SensorFormatting.number(location?.speed, digits: 2, unit: "m/s"), fallbackStatus: status)
                ReadingRow("Altitude", value: SensorFormatting.number(location?.altitude, digits: 1, unit: "m"), fallbackStatus: status)
                ReadingRow("Course", value: SensorFormatting.number(location?.course, digits: 1, unit: "deg"), fallbackStatus: status)
            }

            Section("Motion") {
                let motion = sensorManager.liveState.motion
                let status = sensorManager.liveState.motionStatus
                ReadingRow("User Acceleration X", value: SensorFormatting.number(motion?.userAccelerationX, digits: 3, unit: "g"), fallbackStatus: status)
                ReadingRow("User Acceleration Y", value: SensorFormatting.number(motion?.userAccelerationY, digits: 3, unit: "g"), fallbackStatus: status)
                ReadingRow("User Acceleration Z", value: SensorFormatting.number(motion?.userAccelerationZ, digits: 3, unit: "g"), fallbackStatus: status)
                ReadingRow("Gravity X", value: SensorFormatting.number(motion?.gravityX, digits: 3, unit: "g"), fallbackStatus: status)
                ReadingRow("Gravity Y", value: SensorFormatting.number(motion?.gravityY, digits: 3, unit: "g"), fallbackStatus: status)
                ReadingRow("Gravity Z", value: SensorFormatting.number(motion?.gravityZ, digits: 3, unit: "g"), fallbackStatus: status)
                ReadingRow("Rotation Rate X", value: SensorFormatting.number(motion?.rotationRateX, digits: 3, unit: "rad/s"), fallbackStatus: status)
                ReadingRow("Rotation Rate Y", value: SensorFormatting.number(motion?.rotationRateY, digits: 3, unit: "rad/s"), fallbackStatus: status)
                ReadingRow("Rotation Rate Z", value: SensorFormatting.number(motion?.rotationRateZ, digits: 3, unit: "rad/s"), fallbackStatus: status)
                ReadingRow("Roll", value: SensorFormatting.number(motion?.roll, digits: 3, unit: "rad"), fallbackStatus: status)
                ReadingRow("Pitch", value: SensorFormatting.number(motion?.pitch, digits: 3, unit: "rad"), fallbackStatus: status)
                ReadingRow("Yaw", value: SensorFormatting.number(motion?.yaw, digits: 3, unit: "rad"), fallbackStatus: status)
            }

            Section("Barometer") {
                let barometer = sensorManager.liveState.barometer
                let status = sensorManager.liveState.barometerStatus
                ReadingRow("Relative Altitude", value: SensorFormatting.number(barometer?.relativeAltitude, digits: 2, unit: "m"), fallbackStatus: status)
                ReadingRow("Pressure", value: SensorFormatting.number(barometer?.pressure, digits: 1, unit: "hPa"), fallbackStatus: status)
            }

            Section("Pedometer") {
                let pedometer = sensorManager.liveState.pedometer
                let status = sensorManager.liveState.pedometerStatus
                ReadingRow("Steps", value: SensorFormatting.integer(pedometer?.stepCount), fallbackStatus: status)
                ReadingRow("Distance", value: SensorFormatting.number(pedometer?.distance, digits: 1, unit: "m"), fallbackStatus: status)
                ReadingRow("Floors Ascended", value: SensorFormatting.integer(pedometer?.floorsAscended), fallbackStatus: status)
                ReadingRow("Floors Descended", value: SensorFormatting.integer(pedometer?.floorsDescended), fallbackStatus: status)
            }

            Section("Activity") {
                let activity = sensorManager.liveState.activity
                let status = sensorManager.liveState.activityStatus
                ReadingRow("Activity Type", value: localizedValue(activity?.type?.titleKey), fallbackStatus: status)
                ReadingRow("Confidence", value: localizedValue(activity?.confidence?.titleKey), fallbackStatus: status)
            }

            Section("Device") {
                let device = sensorManager.liveState.device
                let status = sensorManager.liveState.deviceStatus
                ReadingRow("Battery Level", value: SensorFormatting.percent(device.batteryLevel), fallbackStatus: status)
                ReadingRow("Battery State", value: localizedValue(device.batteryState.titleKey), fallbackStatus: status)
                ReadingRow("Low Power Mode", value: localizedValue(device.isLowPowerModeEnabled ? "On" : "Off"), fallbackStatus: status)
                ReadingRow("Thermal State", value: localizedValue(device.thermalState.titleKey), fallbackStatus: status)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("SensorLog")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saveSnapshot()
                } label: {
                    Label("Save", systemImage: "tray.and.arrow.down")
                }
            }
        }
        .task {
            sensorManager.start()
        }
        .alert(item: $feedback) { feedback in
            Alert(
                title: Text(LocalizedStringKey(feedback.titleKey)),
                message: Text(feedback.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private var locationPermissionAction: some View {
        switch sensorManager.permissions.location {
        case .authorizedWhenInUse:
            Label("Location Ready", systemImage: "location.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.teal)
        case .denied, .restricted:
            Button {
                openAppSettings()
            } label: {
                Label("Open Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .notDetermined:
            Button {
                sensorManager.requestLocationPermission()
            } label: {
                Label("Request Location", systemImage: "location")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var motionPermissionAction: some View {
        switch sensorManager.permissions.motion {
        case .available:
            Label("Motion Ready", systemImage: "figure.walk")
                .font(.caption.weight(.medium))
                .foregroundStyle(.teal)
        case .deniedRestricted:
            Button {
                openAppSettings()
            } label: {
                Label("Open Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .unknown:
            Button {
                sensorManager.requestMotionPermission()
            } label: {
                Label("Request Motion", systemImage: "figure.walk")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func saveSnapshot() {
        let snapshot = SensorSnapshot(liveState: sensorManager.liveState)
        modelContext.insert(snapshot)

        do {
            try modelContext.save()
            feedback = SaveFeedback(titleKey: "Snapshot Saved", message: String(localized: "The current sensor state was saved locally."))
        } catch {
            modelContext.rollback()
            feedback = SaveFeedback(titleKey: "Save Failed", message: error.localizedDescription)
            return
        }

        do {
            try pruneOldSnapshots()
        } catch {
            feedback = SaveFeedback(titleKey: "Snapshot Saved", message: String(localized: "The snapshot was saved, but old snapshot cleanup failed."))
        }
    }

    private func pruneOldSnapshots() throws {
        let descriptor = FetchDescriptor<SensorSnapshot>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let snapshots = try modelContext.fetch(descriptor)
        let overflow = snapshots.count - 500
        guard overflow > 0 else { return }

        for snapshot in snapshots.prefix(overflow) {
            modelContext.delete(snapshot)
        }
        try modelContext.save()
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func localizedValue(_ key: String?) -> String? {
        guard let key else { return nil }
        return String(localized: String.LocalizationValue(key))
    }
}

private struct SaveFeedback: Identifiable {
    let id = UUID()
    var titleKey: String
    var message: String
}

#Preview {
    NavigationStack {
        SensorsView()
            .environment(SensorManager.preview)
            .modelContainer(for: SensorSnapshot.self, inMemory: true)
    }
}
