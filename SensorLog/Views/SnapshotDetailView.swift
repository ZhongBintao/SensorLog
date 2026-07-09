import SwiftData
import SwiftUI

struct SnapshotDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let snapshot: SensorSnapshot

    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Snapshot") {
                ReadingRow("Saved At", value: SensorFormatting.dateTime(snapshot.createdAt), fallbackStatus: .available)
                ReadingRow("Identifier", value: snapshot.id.uuidString, fallbackStatus: .available)
            }

            Section("Location") {
                let status = snapshot.hasLocationData ? ReadingStatus.available : .unavailable
                ReadingRow("Latitude", value: SensorFormatting.number(snapshot.latitude, digits: 6, unit: "deg"), fallbackStatus: status)
                ReadingRow("Longitude", value: SensorFormatting.number(snapshot.longitude, digits: 6, unit: "deg"), fallbackStatus: status)
                ReadingRow("Horizontal Accuracy", value: SensorFormatting.number(snapshot.horizontalAccuracy, digits: 1, unit: "m"), fallbackStatus: status)
                ReadingRow("Speed", value: SensorFormatting.number(snapshot.speed, digits: 2, unit: "m/s"), fallbackStatus: status)
                ReadingRow("Altitude", value: SensorFormatting.number(snapshot.altitude, digits: 1, unit: "m"), fallbackStatus: status)
                ReadingRow("Course", value: SensorFormatting.number(snapshot.course, digits: 1, unit: "deg"), fallbackStatus: status)
            }

            Section("Motion") {
                let status = snapshot.hasMotionData ? ReadingStatus.available : .unavailable
                ReadingRow("User Acceleration X", value: SensorFormatting.number(snapshot.userAccelerationX, digits: 3, unit: "g"), fallbackStatus: status)
                ReadingRow("User Acceleration Y", value: SensorFormatting.number(snapshot.userAccelerationY, digits: 3, unit: "g"), fallbackStatus: status)
                ReadingRow("User Acceleration Z", value: SensorFormatting.number(snapshot.userAccelerationZ, digits: 3, unit: "g"), fallbackStatus: status)
                ReadingRow("Gravity X", value: SensorFormatting.number(snapshot.gravityX, digits: 3, unit: "g"), fallbackStatus: status)
                ReadingRow("Gravity Y", value: SensorFormatting.number(snapshot.gravityY, digits: 3, unit: "g"), fallbackStatus: status)
                ReadingRow("Gravity Z", value: SensorFormatting.number(snapshot.gravityZ, digits: 3, unit: "g"), fallbackStatus: status)
                ReadingRow("Rotation Rate X", value: SensorFormatting.number(snapshot.rotationRateX, digits: 3, unit: "rad/s"), fallbackStatus: status)
                ReadingRow("Rotation Rate Y", value: SensorFormatting.number(snapshot.rotationRateY, digits: 3, unit: "rad/s"), fallbackStatus: status)
                ReadingRow("Rotation Rate Z", value: SensorFormatting.number(snapshot.rotationRateZ, digits: 3, unit: "rad/s"), fallbackStatus: status)
                ReadingRow("Roll", value: SensorFormatting.number(snapshot.roll, digits: 3, unit: "rad"), fallbackStatus: status)
                ReadingRow("Pitch", value: SensorFormatting.number(snapshot.pitch, digits: 3, unit: "rad"), fallbackStatus: status)
                ReadingRow("Yaw", value: SensorFormatting.number(snapshot.yaw, digits: 3, unit: "rad"), fallbackStatus: status)
            }

            Section("Barometer") {
                let status = snapshot.hasBarometerData ? ReadingStatus.available : .unavailable
                ReadingRow("Relative Altitude", value: SensorFormatting.number(snapshot.relativeAltitude, digits: 2, unit: "m"), fallbackStatus: status)
                ReadingRow("Pressure", value: SensorFormatting.number(snapshot.pressure, digits: 1, unit: "hPa"), fallbackStatus: status)
            }

            Section("Pedometer") {
                let status = snapshot.hasPedometerData ? ReadingStatus.available : .unavailable
                ReadingRow("Steps", value: SensorFormatting.integer(snapshot.stepCount), fallbackStatus: status)
                ReadingRow("Distance", value: SensorFormatting.number(snapshot.distance, digits: 1, unit: "m"), fallbackStatus: status)
                ReadingRow("Floors Ascended", value: SensorFormatting.integer(snapshot.floorsAscended), fallbackStatus: status)
                ReadingRow("Floors Descended", value: SensorFormatting.integer(snapshot.floorsDescended), fallbackStatus: status)
            }

            Section("Activity") {
                let status = snapshot.hasActivityData ? ReadingStatus.available : .unavailable
                LocalizedReadingRow("Activity Type", valueKey: activityTypeKey, fallbackStatus: status)
                LocalizedReadingRow("Confidence", valueKey: activityConfidenceKey, fallbackStatus: status)
            }

            Section("Device") {
                let status = snapshot.hasDeviceData ? ReadingStatus.available : .unavailable
                ReadingRow("Battery Level", value: SensorFormatting.percent(snapshot.batteryLevel), fallbackStatus: status)
                LocalizedReadingRow("Battery State", valueKey: batteryStateKey, fallbackStatus: status)
                LocalizedReadingRow("Low Power Mode", valueKey: lowPowerModeKey, fallbackStatus: status)
                LocalizedReadingRow("Thermal State", valueKey: thermalStateKey, fallbackStatus: status)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Snapshot Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let payload = sharePayload {
                    ShareLink(item: payload) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(Text("Share JSON"))
                }

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(Text("Delete Snapshot"))
            }
        }
        .alert("Delete Snapshot?", isPresented: $isConfirmingDelete) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSnapshot()
            }
        } message: {
            Text("This removes the selected local snapshot.")
        }
        .alert("Snapshot Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var sharePayload: String? {
        do {
            return try snapshot.exportJSONString()
        } catch {
            return nil
        }
    }

    private var activityTypeKey: String? {
        guard let rawValue = snapshot.activityType,
              let activity = ActivityType(rawValue: rawValue) else { return nil }
        return activity.titleKey
    }

    private var activityConfidenceKey: String? {
        guard let rawValue = snapshot.activityConfidence,
              let confidence = ActivityConfidence(rawValue: rawValue) else { return nil }
        return confidence.titleKey
    }

    private var batteryStateKey: String? {
        guard let rawValue = snapshot.batteryState,
              let state = BatteryChargeState(rawValue: rawValue) else { return nil }
        return state.titleKey
    }

    private var lowPowerModeKey: String? {
        guard let isLowPowerModeEnabled = snapshot.isLowPowerModeEnabled else { return nil }
        return isLowPowerModeEnabled ? "On" : "Off"
    }

    private var thermalStateKey: String? {
        guard let rawValue = snapshot.thermalState,
              let state = ThermalStateDisplay(rawValue: rawValue) else { return nil }
        return state.titleKey
    }

    private func deleteSnapshot() {
        modelContext.delete(snapshot)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
