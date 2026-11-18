import SwiftData
import SwiftUI
import UIKit

struct SnapshotDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let snapshot: SensorSnapshot

    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?
    @State private var errorTitleKey = "Snapshot Error"
    @State private var sharePayload: SnapshotSharePayload?

    var body: some View {
        List {
            Section("Snapshot") {
                ReadingRow("Saved At", value: SensorFormatting.dateTime(snapshot.createdAt), fallbackStatus: .available)
                ReadingRow("Identifier", value: snapshot.id.uuidString, fallbackStatus: .available)
            }

            Section("Quality Analysis") {
                if snapshot.hasQualityAnalysis {
                    LocalizedReadingRow("Smoothing Mode", valueKey: snapshot.savedSmoothingMode?.titleKey, fallbackStatus: .unavailable)
                    LocalizedReadingRow("Motion State", valueKey: savedMotionStateKey, fallbackStatus: .unavailable)
                } else {
                    LocalizedReadingRow("Quality Analysis", valueKey: "No Quality Analysis", fallbackStatus: .unavailable)
                }
            }

            Section("Location") {
                let status = snapshot.hasLocationData ? ReadingStatus.available : .unavailable
                if snapshot.hasQualityAnalysis {
                    QualityRow(assessment: snapshot.savedLocationQuality)
                    QualityWarningsView(warnings: snapshot.savedLocationQuality?.warnings ?? [])
                }
                ReadingRow("Latitude", value: SensorFormatting.number(snapshot.latitude, digits: 6, unit: "deg"), fallbackStatus: status)
                ReadingRow("Longitude", value: SensorFormatting.number(snapshot.longitude, digits: 6, unit: "deg"), fallbackStatus: status)
                ReadingRow("Horizontal Accuracy", value: SensorFormatting.number(snapshot.horizontalAccuracy, digits: 1, unit: "m"), fallbackStatus: status)
                ReadingRow("Vertical Accuracy", value: SensorFormatting.number(snapshot.verticalAccuracy, digits: 1, unit: "m"), fallbackStatus: status)
                ReadingRow("Last Updated Age", value: SensorFormatting.elapsed(since: snapshot.lastUpdatedAt, now: snapshot.createdAt), fallbackStatus: status)
                ReadingRow("Speed", value: SensorFormatting.number(snapshot.speed, digits: 2, unit: "m/s"), fallbackStatus: status)
                LocalizedReadingRow("Speed Credibility", valueKey: savedSpeedCredibilityKey, fallbackStatus: status)
                ReadingRow("Altitude", value: SensorFormatting.number(snapshot.altitude, digits: 1, unit: "m"), fallbackStatus: status)
                ReadingRow("Course", value: SensorFormatting.number(snapshot.course, digits: 1, unit: "deg"), fallbackStatus: status)
                LocalizedReadingRow("Course Credibility", valueKey: savedCourseCredibilityKey, fallbackStatus: status)
            }

            Section("Motion") {
                let status = snapshot.hasMotionData ? ReadingStatus.available : .unavailable
                let statistics = snapshot.savedMotionWindowStatistics
                if snapshot.hasQualityAnalysis {
                    QualityRow(assessment: snapshot.savedMotionQuality)
                    QualityWarningsView(warnings: snapshot.savedMotionQuality?.warnings ?? [])
                    ReadingRow("Sample Count", value: SensorFormatting.integer(statistics?.userAccelerationMagnitude.sampleCount), fallbackStatus: status)
                    ReadingRow("Sample Rate", value: SensorFormatting.number(statistics?.userAccelerationMagnitude.actualSampleRate, digits: 1, unit: "Hz"), fallbackStatus: status)
                    ReadingRow("Acceleration Noise", value: SensorFormatting.number(statistics?.userAccelerationMagnitude.standardDeviation, digits: 4, unit: "g"), fallbackStatus: status)
                    ReadingRow("Gyroscope Noise", value: SensorFormatting.number(statistics?.rotationRateMagnitude.standardDeviation, digits: 4, unit: "rad/s"), fallbackStatus: status)
                }
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
                let statistics = snapshot.savedBarometerWindowStatistics
                if snapshot.hasQualityAnalysis {
                    QualityRow(assessment: snapshot.savedBarometerQuality)
                    QualityWarningsView(warnings: snapshot.savedBarometerQuality?.warnings ?? [])
                    ReadingRow("Pressure Range", value: SensorFormatting.range(statistics?.pressure, digits: 2, unit: "hPa"), fallbackStatus: status)
                    ReadingRow("Altitude Range", value: SensorFormatting.range(statistics?.relativeAltitude, digits: 2, unit: "m"), fallbackStatus: status)
                }
                ReadingRow("Relative Altitude", value: SensorFormatting.number(snapshot.relativeAltitude, digits: 2, unit: "m"), fallbackStatus: status)
                ReadingRow("Pressure", value: SensorFormatting.number(snapshot.pressure, digits: 1, unit: "hPa"), fallbackStatus: status)
            }

            Section("Pedometer") {
                let status = snapshot.hasPedometerData ? ReadingStatus.available : .unavailable
                if snapshot.hasQualityAnalysis {
                    QualityRow(assessment: snapshot.savedPedometerQuality)
                    QualityWarningsView(warnings: snapshot.savedPedometerQuality?.warnings ?? [])
                }
                ReadingRow("Steps", value: SensorFormatting.integer(snapshot.stepCount), fallbackStatus: status)
                ReadingRow("Distance", value: SensorFormatting.number(snapshot.distance, digits: 1, unit: "m"), fallbackStatus: status)
                ReadingRow("Floors Ascended", value: SensorFormatting.integer(snapshot.floorsAscended), fallbackStatus: status)
                ReadingRow("Floors Descended", value: SensorFormatting.integer(snapshot.floorsDescended), fallbackStatus: status)
            }

            Section("Activity") {
                let status = snapshot.hasActivityData ? ReadingStatus.available : .unavailable
                if snapshot.hasQualityAnalysis {
                    QualityRow(assessment: snapshot.savedActivityQuality)
                    QualityWarningsView(warnings: snapshot.savedActivityQuality?.warnings ?? [])
                }
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
                Button {
                    prepareSharePayload()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text("Share JSON"))

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
        .alert(Text(LocalizedStringKey(errorTitleKey)), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: $sharePayload) { payload in
            SnapshotActivityShareSheet(items: [payload.content])
        }
    }

    private func prepareSharePayload() {
        do {
            sharePayload = SnapshotSharePayload(content: try snapshot.exportJSONString())
        } catch {
            errorTitleKey = "Share Failed"
            errorMessage = error.localizedDescription
        }
    }

    private var activityTypeKey: String? {
        guard let rawValue = snapshot.activityType,
              let activity = ActivityType(rawValue: rawValue) else { return nil }
        return activity.titleKey
    }

    private var savedMotionStateKey: String? {
        guard let isMotionStationary = snapshot.isMotionStationary else { return nil }
        return isMotionStationary ? "Stationary" : "Moving"
    }

    private var savedSpeedCredibilityKey: String? {
        guard let quality = snapshot.savedLocationQuality else { return "No Quality Analysis" }
        let warnings = quality.warnings
        if warnings.contains(.invalidSpeed) { return "Low" }
        guard snapshot.speed != nil else { return nil }
        return warnings.contains(.lowSpeedCredibility) ? "Low" : "High"
    }

    private var savedCourseCredibilityKey: String? {
        guard let quality = snapshot.savedLocationQuality else { return "No Quality Analysis" }
        if quality.warnings.contains(.invalidCourse) { return "Low" }
        guard snapshot.course != nil else { return nil }
        return "High"
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
            errorTitleKey = "Snapshot Error"
            errorMessage = error.localizedDescription
        }
    }
}

private struct SnapshotSharePayload: Identifiable {
    let id = UUID()
    let content: String
}

private struct SnapshotActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
