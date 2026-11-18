import SwiftData
import SwiftUI
import UIKit

struct SensorsView: View {
    @Environment(SensorManager.self) private var sensorManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("sensorSmoothingMode") private var smoothingModeRawValue = SmoothingMode.raw.rawValue
    @State private var feedback: SaveFeedback?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                liveStatusCard

                if let errorMessage = sensorManager.lastErrorMessage {
                    SensorErrorBanner(message: errorMessage) {
                        sensorManager.dismissLastError()
                    }
                }

                NavigationLink {
                    MotionDetailView(smoothingMode: smoothingMode)
                } label: {
                    MotionOverviewCard(
                        status: sensorManager.liveState.motionStatus,
                        quality: sensorManager.liveState.motionQuality,
                        motionStateKey: motionStateKey,
                        samplingStabilityKey: samplingStabilityKey,
                        accelerationMagnitude: displayedMotion?.userAccelerationMagnitude,
                        sampleRate: sensorManager.liveState.motionWindowStatistics?.userAccelerationMagnitude.actualSampleRate,
                        samples: sensorManager.trendState.motionAcceleration,
                        smoothingMode: smoothingMode
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    EnvironmentDetailView(smoothingMode: smoothingMode)
                } label: {
                    EnvironmentOverviewCard(
                        location: sensorManager.liveState.location,
                        locationStatus: sensorManager.liveState.locationStatus,
                        locationQuality: sensorManager.liveState.locationQuality,
                        barometer: displayedBarometer,
                        barometerStatus: sensorManager.liveState.barometerStatus,
                        barometerQuality: sensorManager.liveState.barometerQuality,
                        barometerStatistics: sensorManager.liveState.barometerWindowStatistics,
                        speedCredibilityKey: speedCredibilityKey,
                        courseCredibilityKey: courseCredibilityKey,
                        locationSamples: sensorManager.trendState.locationAccuracy,
                        pressureSamples: sensorManager.trendState.barometerPressure,
                        smoothingMode: smoothingMode
                    )
                }
                .buttonStyle(.plain)

                Text(LocalizedStringKey("Supporting Sensors"))
                    .font(.headline)
                    .padding(.top, 4)

                LazyVGrid(columns: supportingColumns, alignment: .leading, spacing: 12) {
                    PedometerOverviewCard(
                        reading: sensorManager.liveState.pedometer,
                        status: sensorManager.liveState.pedometerStatus,
                        quality: sensorManager.liveState.pedometerQuality
                    )
                    ActivityOverviewCard(
                        reading: sensorManager.liveState.activity,
                        status: sensorManager.liveState.activityStatus,
                        quality: sensorManager.liveState.activityQuality
                    )
                }

                DeviceOverviewCard(
                    reading: sensorManager.liveState.device,
                    status: sensorManager.liveState.deviceStatus
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("SensorLog")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saveSnapshot()
                } label: {
                    Label("Save Snapshot", systemImage: "tray.and.arrow.down")
                }
            }
        }
        .task {
            sensorManager.setSmoothingMode(smoothingMode)
            sensorManager.start()
        }
        .onChange(of: smoothingModeRawValue) { _, _ in
            sensorManager.setSmoothingMode(smoothingMode)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                sensorManager.start()
            }
        }
        .alert(item: $feedback) { feedback in
            Alert(
                title: Text(LocalizedStringKey(feedback.titleKey)),
                message: feedback.messageText,
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var liveStatusCard: some View {
        SensorCard {
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        SensorCardTitle(titleKey: "Live Status", systemImage: "waveform.path.ecg", tint: .teal)
                        Spacer(minLength: 12)
                        liveStatusBadges
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        SensorCardTitle(titleKey: "Live Status", systemImage: "waveform.path.ecg", tint: .teal)
                        liveStatusBadges
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        locationPermissionAction
                        motionPermissionAction
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        locationPermissionAction
                        motionPermissionAction
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey("Display Values"))
                        .font(.subheadline.weight(.medium))
                    Picker("Display Values", selection: $smoothingModeRawValue) {
                        ForEach(SmoothingMode.allCases) { mode in
                            Text(LocalizedStringKey(mode.titleKey))
                                .tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey("SensorLog asks for permissions only when a related reading needs access."))
                    Text(LocalizedStringKey("Smoothed values affect display only. Snapshots keep raw readings."))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var liveStatusBadges: some View {
        HStack(spacing: 6) {
            StatusBadge(titleKey: "Location", status: sensorManager.liveState.locationStatus)
            StatusBadge(titleKey: "Motion", status: sensorManager.liveState.motionStatus)
        }
    }

    private var supportingColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: 12)]
        }
        return [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var smoothingMode: SmoothingMode {
        SmoothingMode(rawValue: smoothingModeRawValue) ?? .raw
    }

    private var displayedMotion: MotionReading? {
        switch smoothingMode {
        case .raw:
            sensorManager.liveState.motion
        case .smoothed:
            (sensorManager.liveState.smoothedMotion ?? sensorManager.liveState.motion)?.applyingDisplayDeadband()
        }
    }

    private var displayedBarometer: BarometerReading? {
        switch smoothingMode {
        case .raw:
            sensorManager.liveState.barometer
        case .smoothed:
            sensorManager.liveState.smoothedBarometer ?? sensorManager.liveState.barometer
        }
    }

    private var motionStateKey: String? {
        guard let isMotionStationary = sensorManager.liveState.isMotionStationary else { return nil }
        return isMotionStationary ? "Stationary" : "Moving"
    }

    private var samplingStabilityKey: String? {
        guard let statistics = sensorManager.liveState.motionWindowStatistics else { return nil }
        return statistics.isSampleTimingStable ? "Stable" : "Needs Attention"
    }

    private var speedCredibilityKey: String? {
        let warnings = sensorManager.liveState.locationQuality.warnings
        if warnings.contains(.invalidSpeed) { return "Low" }
        guard sensorManager.liveState.location?.speed != nil else { return nil }
        return warnings.contains(.lowSpeedCredibility) ? "Low" : "High"
    }

    private var courseCredibilityKey: String? {
        let warnings = sensorManager.liveState.locationQuality.warnings
        if warnings.contains(.invalidCourse) { return "Low" }
        guard sensorManager.liveState.location?.course != nil else { return nil }
        return "High"
    }

    @ViewBuilder
    private var locationPermissionAction: some View {
        switch sensorManager.permissions.location {
        case .authorizedWhenInUse:
            Label("Location Enabled", systemImage: "location.fill")
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
                Label("Enable Location", systemImage: "location")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var motionPermissionAction: some View {
        switch sensorManager.permissions.motion {
        case .available:
            Label("Motion Enabled", systemImage: "figure.walk")
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
                Label("Enable Motion", systemImage: "figure.walk")
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
            feedback = SaveFeedback(titleKey: "Snapshot Saved", messageKey: "Saved on this iPhone.")
        } catch {
            modelContext.rollback()
            feedback = SaveFeedback(titleKey: "Save Failed", rawMessage: error.localizedDescription)
            return
        }

        do {
            try SnapshotRetentionPolicy.pruneOldestSnapshots(in: modelContext)
        } catch {
            modelContext.rollback()
            feedback = SaveFeedback(titleKey: "Snapshot Saved", messageKey: "Saved, but old snapshot cleanup failed.")
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct MotionOverviewCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let status: ReadingStatus
    let quality: QualityAssessment
    let motionStateKey: String?
    let samplingStabilityKey: String?
    let accelerationMagnitude: Double?
    let sampleRate: Double?
    let samples: [SensorTrendSample]
    let smoothingMode: SmoothingMode

    var body: some View {
        SensorCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    SensorCardTitle(titleKey: "Motion", systemImage: "gyroscope", tint: quality.level.tint)
                    Spacer(minLength: 8)
                    QualityBadge(level: quality.level)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }

                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 12) {
                    metrics
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey("Recent 60 Seconds"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    SensorTrendChart(
                        samples: samples,
                        mode: smoothingMode,
                        tint: quality.level.tint,
                        accessibilityLabelKey: "Acceleration Magnitude",
                        unit: "g",
                        minimumVisibleRange: 0.03
                    )
                }

            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private var metrics: some View {
        LocalizedSensorMetric(titleKey: "Motion State", valueKey: motionStateKey, fallbackStatus: analysisStatus)
        LocalizedSensorMetric(titleKey: "Sampling Stability", valueKey: samplingStabilityKey, fallbackStatus: analysisStatus)
        SensorMetric(
            titleKey: "Acceleration Magnitude",
            value: SensorFormatting.number(accelerationMagnitude, digits: 3, unit: "g"),
            fallbackStatus: status
        )
        SensorMetric(
            titleKey: "Sample Rate",
            value: SensorFormatting.number(sampleRate, digits: 1, unit: "Hz"),
            fallbackStatus: analysisStatus
        )
    }

    private var analysisStatus: ReadingStatus {
        status == .available ? .waiting : status
    }

    private var metricColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var accessibilitySummary: Text {
        Text(LocalizedStringKey("Motion")) + Text(verbatim: ". ") +
            Text(LocalizedStringKey("Quality")) + Text(verbatim: ": ") +
            Text(LocalizedStringKey(quality.level.titleKey)) + Text(verbatim: ". ") +
            Text(LocalizedStringKey("Motion State")) + Text(verbatim: ": ") +
            localizedValueText(motionStateKey, fallbackStatus: analysisStatus) + Text(verbatim: ". ") +
            Text(LocalizedStringKey("Sampling Stability")) + Text(verbatim: ": ") +
            localizedValueText(samplingStabilityKey, fallbackStatus: analysisStatus) + Text(verbatim: ". ") +
            Text(LocalizedStringKey("Acceleration Magnitude")) + Text(verbatim: ": ") +
            formattedValueText(
                SensorFormatting.number(accelerationMagnitude, digits: 3, unit: "g"),
                fallbackStatus: status
            ) + Text(verbatim: ". ") +
            Text(LocalizedStringKey("Sample Rate")) + Text(verbatim: ": ") +
            formattedValueText(
                SensorFormatting.number(sampleRate, digits: 1, unit: "Hz"),
                fallbackStatus: analysisStatus
            )
    }

    private func localizedValueText(_ valueKey: String?, fallbackStatus: ReadingStatus) -> Text {
        valueKey.map { Text(LocalizedStringKey($0)) }
            ?? Text(LocalizedStringKey(fallbackStatus.titleKey))
    }

    private func formattedValueText(_ value: String?, fallbackStatus: ReadingStatus) -> Text {
        value.map { Text(verbatim: $0) }
            ?? Text(LocalizedStringKey(fallbackStatus.titleKey))
    }
}

private struct EnvironmentOverviewCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let location: LocationReading?
    let locationStatus: ReadingStatus
    let locationQuality: QualityAssessment
    let barometer: BarometerReading?
    let barometerStatus: ReadingStatus
    let barometerQuality: QualityAssessment
    let barometerStatistics: BarometerWindowStatistics?
    let speedCredibilityKey: String?
    let courseCredibilityKey: String?
    let locationSamples: [SensorTrendSample]
    let pressureSamples: [SensorTrendSample]
    let smoothingMode: SmoothingMode

    var body: some View {
        SensorCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    SensorCardTitle(titleKey: "Environment", systemImage: "location.viewfinder", tint: .blue)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) {
                        qualitySummaries
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        qualitySummaries
                    }
                }

                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 12) {
                    environmentMetrics
                }

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        environmentTrends
                    }
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        environmentTrends
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private var qualitySummaries: some View {
        HStack(spacing: 6) {
            Text(LocalizedStringKey("Location"))
                .font(.caption)
                .foregroundStyle(.secondary)
            QualityBadge(level: locationQuality.level)
        }
        HStack(spacing: 6) {
            Text(LocalizedStringKey("Barometer"))
                .font(.caption)
                .foregroundStyle(.secondary)
            QualityBadge(level: barometerQuality.level)
        }
    }

    @ViewBuilder
    private var environmentMetrics: some View {
        SensorMetric(
            titleKey: "Location",
            value: coordinate,
            fallbackStatus: locationStatus
        )
        SensorMetric(
            titleKey: "Horizontal Accuracy",
            value: SensorFormatting.number(location?.horizontalAccuracy, digits: 1, unit: "m"),
            fallbackStatus: locationStatus
        )
        SensorMetric(
            titleKey: "Vertical Accuracy",
            value: SensorFormatting.number(location?.verticalAccuracy, digits: 1, unit: "m"),
            fallbackStatus: locationStatus
        )
        SensorMetric(
            titleKey: "Last Updated Age",
            value: SensorFormatting.elapsed(since: location?.lastUpdatedAt),
            fallbackStatus: locationStatus
        )
        LocalizedSensorMetric(
            titleKey: "Speed Credibility",
            valueKey: speedCredibilityKey,
            fallbackStatus: locationStatus
        )
        LocalizedSensorMetric(
            titleKey: "Course Credibility",
            valueKey: courseCredibilityKey,
            fallbackStatus: locationStatus
        )
        SensorMetric(
            titleKey: "Pressure",
            value: SensorFormatting.number(barometer?.pressure, digits: 1, unit: "hPa"),
            fallbackStatus: barometerStatus
        )
        SensorMetric(
            titleKey: "Relative Altitude",
            value: SensorFormatting.number(barometer?.relativeAltitude, digits: 2, unit: "m"),
            fallbackStatus: barometerStatus
        )
        SensorMetric(
            titleKey: "Pressure Range",
            value: SensorFormatting.range(barometerStatistics?.pressure, digits: 2, unit: "hPa"),
            fallbackStatus: barometerAnalysisStatus
        )
        SensorMetric(
            titleKey: "Altitude Range",
            value: SensorFormatting.range(barometerStatistics?.relativeAltitude, digits: 2, unit: "m"),
            fallbackStatus: barometerAnalysisStatus
        )
    }

    private func trend(
        titleKey: String,
        samples: [SensorTrendSample],
        mode: SmoothingMode,
        tint: Color,
        unit: String,
        minimumVisibleRange: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(titleKey))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            SensorTrendChart(
                samples: samples,
                mode: mode,
                tint: tint,
                accessibilityLabelKey: titleKey,
                unit: unit,
                minimumVisibleRange: minimumVisibleRange,
                height: 62
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var coordinate: String? {
        guard let latitude = SensorFormatting.number(location?.latitude, digits: 4),
              let longitude = SensorFormatting.number(location?.longitude, digits: 4) else { return nil }
        return "\(latitude), \(longitude)"
    }

    private var barometerAnalysisStatus: ReadingStatus {
        barometerStatus == .available ? .waiting : barometerStatus
    }

    @ViewBuilder
    private var environmentTrends: some View {
        trend(
            titleKey: "Location Accuracy Trend",
            samples: locationSamples,
            mode: .raw,
            tint: locationQuality.level.tint,
            unit: "m",
            minimumVisibleRange: 25
        )
        trend(
            titleKey: "Pressure Trend",
            samples: pressureSamples,
            mode: smoothingMode,
            tint: barometerQuality.level.tint,
            unit: "hPa",
            minimumVisibleRange: 1
        )
    }

    private var metricColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var accessibilitySummary: Text {
        Text(LocalizedStringKey("Environment")) + Text(verbatim: ". ") +
            Text(LocalizedStringKey("Location")) + Text(verbatim: " ") +
            Text(LocalizedStringKey("Quality")) + Text(verbatim: ": ") +
            Text(LocalizedStringKey(locationQuality.level.titleKey)) + Text(verbatim: ". ") +
            Text(LocalizedStringKey("Barometer")) + Text(verbatim: " ") +
            Text(LocalizedStringKey("Quality")) + Text(verbatim: ": ") +
            Text(LocalizedStringKey(barometerQuality.level.titleKey)) + Text(verbatim: ". ") +
            Text(LocalizedStringKey("Location")) + Text(verbatim: ": ") +
            formattedValueText(coordinate, fallbackStatus: locationStatus) + Text(verbatim: ". ") +
            Text(LocalizedStringKey("Horizontal Accuracy")) + Text(verbatim: ": ") +
            formattedValueText(
                SensorFormatting.number(location?.horizontalAccuracy, digits: 1, unit: "m"),
                fallbackStatus: locationStatus
            ) + Text(verbatim: ". ") +
            Text(LocalizedStringKey("Pressure")) + Text(verbatim: ": ") +
            formattedValueText(
                SensorFormatting.number(barometer?.pressure, digits: 1, unit: "hPa"),
                fallbackStatus: barometerStatus
            )
    }

    private func formattedValueText(_ value: String?, fallbackStatus: ReadingStatus) -> Text {
        value.map { Text(verbatim: $0) }
            ?? Text(LocalizedStringKey(fallbackStatus.titleKey))
    }
}

private struct PedometerOverviewCard: View {
    let reading: PedometerReading?
    let status: ReadingStatus
    let quality: QualityAssessment

    var body: some View {
        SensorCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    SensorCardTitle(titleKey: "Pedometer", systemImage: "figure.walk", tint: quality.level.tint)
                    Spacer(minLength: 4)
                    QualityBadge(level: quality.level)
                }
                SensorMetric(titleKey: "Steps", value: SensorFormatting.integer(reading?.stepCount), fallbackStatus: status)
                SensorMetric(
                    titleKey: "Distance",
                    value: SensorFormatting.number(reading?.distance, digits: 1, unit: "m"),
                    fallbackStatus: status
                )
                HStack(alignment: .top, spacing: 12) {
                    SensorMetric(titleKey: "Floors Ascended", value: SensorFormatting.integer(reading?.floorsAscended), fallbackStatus: status)
                    SensorMetric(titleKey: "Floors Descended", value: SensorFormatting.integer(reading?.floorsDescended), fallbackStatus: status)
                }
            }
        }
    }
}

private struct ActivityOverviewCard: View {
    let reading: ActivityReading?
    let status: ReadingStatus
    let quality: QualityAssessment

    var body: some View {
        SensorCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    SensorCardTitle(titleKey: "Activity", systemImage: "figure.run", tint: quality.level.tint)
                    Spacer(minLength: 4)
                    QualityBadge(level: quality.level)
                }
                LocalizedSensorMetric(titleKey: "Activity Type", valueKey: reading?.type?.titleKey, fallbackStatus: status)
                LocalizedSensorMetric(titleKey: "Confidence", valueKey: reading?.confidence?.titleKey, fallbackStatus: status)
                QualityWarningsView(warnings: Array(quality.warnings.prefix(1)))
            }
        }
    }
}

private struct DeviceOverviewCard: View {
    let reading: DeviceReading
    let status: ReadingStatus

    var body: some View {
        SensorCard {
            VStack(alignment: .leading, spacing: 12) {
                SensorCardTitle(titleKey: "Device", systemImage: "iphone", tint: .indigo)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        metrics
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        metrics
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var metrics: some View {
        SensorMetric(titleKey: "Battery Level", value: SensorFormatting.percent(reading.batteryLevel), fallbackStatus: status)
        LocalizedSensorMetric(titleKey: "Battery State", valueKey: reading.batteryState.titleKey, fallbackStatus: status)
        LocalizedSensorMetric(titleKey: "Low Power Mode", valueKey: reading.isLowPowerModeEnabled ? "On" : "Off", fallbackStatus: status)
        LocalizedSensorMetric(titleKey: "Thermal State", valueKey: reading.thermalState.titleKey, fallbackStatus: status)
    }
}

private struct SaveFeedback: Identifiable {
    let id = UUID()
    var titleKey: String
    var messageKey: String?
    var rawMessage: String?

    var messageText: Text {
        if let messageKey {
            Text(LocalizedStringKey(messageKey))
        } else {
            Text(rawMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        SensorsView()
            .environment(SensorManager.preview)
            .modelContainer(for: SensorSnapshot.self, inMemory: true)
    }
}
