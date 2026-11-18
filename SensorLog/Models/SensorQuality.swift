import Foundation

enum QualityLevel: String, Codable, CaseIterable, Sendable {
    case high
    case medium
    case low

    var titleKey: String {
        switch self {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        }
    }
}

enum SmoothingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case raw
    case smoothed

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .raw: "Raw"
        case .smoothed: "Smoothed"
        }
    }
}

enum QualityWarning: String, Codable, CaseIterable, Sendable {
    case poorHorizontalAccuracy = "poor_horizontal_accuracy"
    case poorVerticalAccuracy = "poor_vertical_accuracy"
    case staleLocation = "stale_location"
    case invalidSpeed = "invalid_speed"
    case invalidCourse = "invalid_course"
    case lowSpeedCredibility = "low_speed_credibility"
    case unstableSampleRate = "unstable_sample_rate"
    case unstableSampleTiming = "unstable_sample_timing"
    case highAccelerationNoise = "high_acceleration_noise"
    case highGyroNoise = "high_gyro_noise"
    case unavailableMotionData = "unavailable_motion_data"
    case pressureFluctuation = "pressure_fluctuation"
    case altitudeDrift = "altitude_drift"
    case unavailableBarometer = "unavailable_barometer"
    case missingPedometerOptionalFields = "missing_pedometer_optional_fields"
    case unavailablePedometer = "unavailable_pedometer"
    case lowActivityConfidence = "low_activity_confidence"
    case unavailableActivity = "unavailable_activity"
    case permissionLimited = "permission_limited"
    case sensorUnavailable = "sensor_unavailable"
    case sensorError = "sensor_error"
    case insufficientSamples = "insufficient_samples"
    case waitingForData = "waiting_for_data"
    case missingRequiredData = "missing_required_data"

    var titleKey: String {
        switch self {
        case .poorHorizontalAccuracy: "Horizontal accuracy is limited."
        case .poorVerticalAccuracy: "Vertical accuracy is limited."
        case .staleLocation: "Location data is out of date."
        case .invalidSpeed: "Speed is not currently reliable."
        case .invalidCourse: "Course is not currently reliable."
        case .lowSpeedCredibility: "Speed may reflect location drift."
        case .unstableSampleRate: "The motion sample rate is outside the expected range."
        case .unstableSampleTiming: "Motion sample timing is unstable."
        case .highAccelerationNoise: "Acceleration changes are noisy."
        case .highGyroNoise: "Rotation changes are noisy."
        case .unavailableMotionData: "Motion data is unavailable."
        case .pressureFluctuation: "Pressure is fluctuating."
        case .altitudeDrift: "Relative altitude is drifting."
        case .unavailableBarometer: "Barometer data is unavailable."
        case .missingPedometerOptionalFields: "Some pedometer details are unavailable."
        case .unavailablePedometer: "Pedometer data is unavailable."
        case .lowActivityConfidence: "Activity confidence is low."
        case .unavailableActivity: "Activity data is unavailable."
        case .permissionLimited: "Permission is limited."
        case .sensorUnavailable: "This sensor is unavailable."
        case .sensorError: "The sensor reading failed."
        case .insufficientSamples: "Collecting more samples."
        case .waitingForData: "Waiting for sensor data."
        case .missingRequiredData: "Required sensor data is missing."
        }
    }
}

struct QualityAssessment: Codable, Equatable, Sendable {
    var level: QualityLevel
    var confidence: Double?
    var warnings: [QualityWarning]

    init(level: QualityLevel, confidence: Double? = nil, warnings: [QualityWarning] = []) {
        self.level = level
        self.confidence = confidence
        self.warnings = warnings.removingDuplicates()
    }
}

struct SampleWindowStatistics: Codable, Equatable, Sendable {
    var sampleCount: Int
    var actualSampleRate: Double?
    var min: Double?
    var max: Double?
    var mean: Double?
    var standardDeviation: Double?

    var stddev: Double? { standardDeviation }
}

struct MotionWindowStatistics: Codable, Equatable, Sendable {
    var userAccelerationMagnitude: SampleWindowStatistics
    var rotationRateMagnitude: SampleWindowStatistics
    var sampleInterval: SampleWindowStatistics
    var isSampleTimingStable: Bool
}

struct BarometerWindowStatistics: Codable, Equatable, Sendable {
    var pressure: SampleWindowStatistics
    var relativeAltitude: SampleWindowStatistics
}

struct MotionQualitySample: Equatable, Sendable {
    var timestamp: TimeInterval
    var userAccelerationMagnitude: Double
    var rotationRateMagnitude: Double
}

struct BarometerQualitySample: Equatable, Sendable {
    var timestamp: TimeInterval
    var pressure: Double
    var relativeAltitude: Double
}

struct MotionQualityResult: Equatable, Sendable {
    var assessment: QualityAssessment
    var statistics: MotionWindowStatistics?
    var isStationary: Bool?
}

struct BarometerQualityResult: Equatable, Sendable {
    var assessment: QualityAssessment
    var statistics: BarometerWindowStatistics?
}

struct SensorQualityConfiguration: Sendable {
    static let `default` = SensorQualityConfiguration()

    var locationHighMaximumAge: TimeInterval = 5
    var locationMediumMaximumAge: TimeInterval = 15
    var locationHighMaximumHorizontalAccuracy: Double = 25
    var locationMediumMaximumHorizontalAccuracy: Double = 100
    var locationHighMaximumVerticalAccuracy: Double = 30
    var locationMediumMaximumVerticalAccuracy: Double = 150
    var locationStationarySpeedConflictThreshold: Double = 0.5
    var locationMaximumCredibleSpeedAccuracy: Double = 3
    var locationMaximumCredibleCourseAccuracy: Double = 45

    var motionWindowDuration: TimeInterval = 3
    var motionMinimumEvaluationDuration: TimeInterval = 1
    var motionMinimumSampleCount: Int = 20
    var motionHighMinimumSampleRate: Double = 40
    var motionHighMaximumSampleRate: Double = 60
    var motionMediumMinimumSampleRate: Double = 20
    var motionMediumMaximumSampleRate: Double = 80
    var motionMaximumSampleIntervalVariationRatio: Double = 0.25
    var motionMaximumSampleGapMultiplier: Double = 2.5
    var motionAccelerationNoiseWarningStandardDeviation: Double = 0.05
    var motionGyroNoiseWarningStandardDeviation: Double = 0.10
    var stationaryMaximumAccelerationMean: Double = 0.03
    var stationaryMaximumAccelerationStandardDeviation: Double = 0.015
    var stationaryMaximumGyroMean: Double = 0.05
    var stationaryMaximumGyroStandardDeviation: Double = 0.03

    var barometerWindowDuration: TimeInterval = 10
    var barometerMinimumSampleCount: Int = 3
    var barometerHighMaximumPressureRange: Double = 1
    var barometerMediumMaximumPressureRange: Double = 3
    var barometerHighMaximumRelativeAltitudeRange: Double = 1.5
    var barometerMediumMaximumRelativeAltitudeRange: Double = 5

    var pedometerWaitingTimeout: TimeInterval = 10
    var smoothingAlpha: Double = 0.25
    var accelerationDisplayZeroThreshold: Double = 0.005
    var rotationRateDisplayZeroThreshold: Double = 0.01
}

enum SensorQualityAnalyzer {
    static func assessLocation(
        status: ReadingStatus,
        reading: LocationReading?,
        now: Date = .now,
        isMotionStationary: Bool?,
        configuration: SensorQualityConfiguration = .default
    ) -> QualityAssessment {
        guard status == .available else {
            return unavailableAssessment(for: status, specificWarning: .missingRequiredData)
        }
        guard let reading,
              reading.latitude != nil,
              reading.longitude != nil,
              let horizontalAccuracy = reading.horizontalAccuracy,
              horizontalAccuracy >= 0,
              let lastUpdatedAt = reading.lastUpdatedAt else {
            return QualityAssessment(level: .low, warnings: [.missingRequiredData])
        }

        let age = max(0, now.timeIntervalSince(lastUpdatedAt))
        let verticalAccuracy = reading.verticalAccuracy
        var warnings: [QualityWarning] = []

        if horizontalAccuracy > configuration.locationHighMaximumHorizontalAccuracy {
            warnings.append(.poorHorizontalAccuracy)
        }
        if let verticalAccuracy,
           verticalAccuracy > configuration.locationHighMaximumVerticalAccuracy {
            warnings.append(.poorVerticalAccuracy)
        }
        if age > configuration.locationHighMaximumAge {
            warnings.append(.staleLocation)
        }

        let speedIsValid = reading.speed != nil && reading.speedAccuracy != nil
        if !speedIsValid {
            warnings.append(.invalidSpeed)
        }
        let courseIsValid = reading.course != nil && reading.courseAccuracy != nil
        if !courseIsValid || (reading.courseAccuracy ?? .infinity) > configuration.locationMaximumCredibleCourseAccuracy {
            warnings.append(.invalidCourse)
        }
        if let speedAccuracy = reading.speedAccuracy,
           speedAccuracy > configuration.locationMaximumCredibleSpeedAccuracy {
            warnings.append(.lowSpeedCredibility)
        }
        if isMotionStationary == true,
           let speed = reading.speed,
           speed > configuration.locationStationarySpeedConflictThreshold {
            warnings.append(.lowSpeedCredibility)
        }

        let verticalIsHigh = verticalAccuracy.map { $0 <= configuration.locationHighMaximumVerticalAccuracy } ?? true
        let verticalIsMedium = verticalAccuracy.map { $0 <= configuration.locationMediumMaximumVerticalAccuracy } ?? true
        let baseLevel: QualityLevel
        if age <= configuration.locationHighMaximumAge,
           horizontalAccuracy <= configuration.locationHighMaximumHorizontalAccuracy,
           verticalIsHigh {
            baseLevel = .high
        } else if age <= configuration.locationMediumMaximumAge,
                  horizontalAccuracy <= configuration.locationMediumMaximumHorizontalAccuracy,
                  verticalIsMedium {
            baseLevel = .medium
        } else {
            baseLevel = .low
        }

        let level = baseLevel == .high && warnings.contains(.lowSpeedCredibility) ? QualityLevel.medium : baseLevel
        return QualityAssessment(level: level, warnings: warnings)
    }

    static func analyzeMotion(
        status: ReadingStatus,
        samples: [MotionQualitySample],
        referenceTimestamp: TimeInterval? = nil,
        configuration: SensorQualityConfiguration = .default
    ) -> MotionQualityResult {
        guard status == .available || status == .waiting else {
            return MotionQualityResult(
                assessment: unavailableAssessment(for: status, specificWarning: .unavailableMotionData),
                statistics: nil,
                isStationary: nil
            )
        }
        guard let latestTimestamp = samples.map(\.timestamp).max() else {
            return MotionQualityResult(
                assessment: QualityAssessment(level: .low, warnings: [.waitingForData]),
                statistics: nil,
                isStationary: nil
            )
        }

        let analysisTimestamp = max(referenceTimestamp ?? latestTimestamp, latestTimestamp)
        let cutoff = analysisTimestamp - configuration.motionWindowDuration
        let window = samples.filter { $0.timestamp >= cutoff }.sorted { $0.timestamp < $1.timestamp }
        let timestamps = window.map(\.timestamp)
        guard window.count >= configuration.motionMinimumSampleCount,
              let firstTimestamp = timestamps.first,
              let lastTimestamp = timestamps.last,
              lastTimestamp - firstTimestamp >= configuration.motionMinimumEvaluationDuration,
              let acceleration = makeStatistics(
                values: window.map(\.userAccelerationMagnitude),
                timestamps: timestamps
              ),
              let rotation = makeStatistics(
                values: window.map(\.rotationRateMagnitude),
                timestamps: timestamps
              ) else {
            return MotionQualityResult(
                assessment: QualityAssessment(level: .low, warnings: [.insufficientSamples]),
                statistics: nil,
                isStationary: nil
            )
        }

        let intervals = zip(timestamps.dropFirst(), timestamps).map(-)
        var intervalStatistics = makeStatistics(values: intervals, timestamps: Array(0..<intervals.count).map(Double.init))
            ?? SampleWindowStatistics(sampleCount: 0, actualSampleRate: nil, min: nil, max: nil, mean: nil, standardDeviation: nil)
        let sampleRate = acceleration.actualSampleRate ?? 0
        intervalStatistics.actualSampleRate = acceleration.actualSampleRate
        let intervalVariationRatio: Double = {
            guard let mean = intervalStatistics.mean, mean > 0,
                  let standardDeviation = intervalStatistics.standardDeviation else { return .infinity }
            return standardDeviation / mean
        }()
        let maximumGapIsStable: Bool = {
            guard sampleRate > 0, let maximumInterval = intervalStatistics.max else { return false }
            return maximumInterval <= configuration.motionMaximumSampleGapMultiplier / sampleRate
        }()
        let trailingGapIsStable = sampleRate > 0 &&
            analysisTimestamp - lastTimestamp <= configuration.motionMaximumSampleGapMultiplier / sampleRate
        let timingIsStable = intervalVariationRatio <= configuration.motionMaximumSampleIntervalVariationRatio &&
            maximumGapIsStable &&
            trailingGapIsStable
        let statistics = MotionWindowStatistics(
            userAccelerationMagnitude: acceleration,
            rotationRateMagnitude: rotation,
            sampleInterval: intervalStatistics,
            isSampleTimingStable: timingIsStable
        )

        var warnings: [QualityWarning] = []
        let rateIsHigh = sampleRate >= configuration.motionHighMinimumSampleRate && sampleRate <= configuration.motionHighMaximumSampleRate
        let rateIsUsable = sampleRate >= configuration.motionMediumMinimumSampleRate && sampleRate <= configuration.motionMediumMaximumSampleRate
        if !rateIsHigh { warnings.append(.unstableSampleRate) }
        if !timingIsStable { warnings.append(.unstableSampleTiming) }
        if (acceleration.standardDeviation ?? .infinity) > configuration.motionAccelerationNoiseWarningStandardDeviation {
            warnings.append(.highAccelerationNoise)
        }
        if (rotation.standardDeviation ?? .infinity) > configuration.motionGyroNoiseWarningStandardDeviation {
            warnings.append(.highGyroNoise)
        }

        let level: QualityLevel
        if rateIsHigh && timingIsStable && !warnings.contains(.highAccelerationNoise) && !warnings.contains(.highGyroNoise) {
            level = .high
        } else if rateIsUsable && timingIsStable {
            level = .medium
        } else {
            level = .low
        }

        let isStationary: Bool? = {
            guard timingIsStable else { return nil }
            guard let accelerationMean = acceleration.mean,
                  let accelerationDeviation = acceleration.standardDeviation,
                  let rotationMean = rotation.mean,
                  let rotationDeviation = rotation.standardDeviation else { return nil }
            return accelerationMean <= configuration.stationaryMaximumAccelerationMean &&
                accelerationDeviation <= configuration.stationaryMaximumAccelerationStandardDeviation &&
                rotationMean <= configuration.stationaryMaximumGyroMean &&
                rotationDeviation <= configuration.stationaryMaximumGyroStandardDeviation
        }()

        return MotionQualityResult(
            assessment: QualityAssessment(level: level, warnings: warnings),
            statistics: statistics,
            isStationary: isStationary
        )
    }

    static func analyzeBarometer(
        status: ReadingStatus,
        samples: [BarometerQualitySample],
        configuration: SensorQualityConfiguration = .default
    ) -> BarometerQualityResult {
        guard status == .available || status == .waiting else {
            return BarometerQualityResult(
                assessment: unavailableAssessment(for: status, specificWarning: .unavailableBarometer),
                statistics: nil
            )
        }
        guard let latestTimestamp = samples.map(\.timestamp).max() else {
            return BarometerQualityResult(
                assessment: QualityAssessment(level: .low, warnings: [.waitingForData]),
                statistics: nil
            )
        }

        let cutoff = latestTimestamp - configuration.barometerWindowDuration
        let window = samples.filter { $0.timestamp >= cutoff }.sorted { $0.timestamp < $1.timestamp }
        let timestamps = window.map(\.timestamp)
        guard window.count >= configuration.barometerMinimumSampleCount,
              let pressure = makeStatistics(values: window.map(\.pressure), timestamps: timestamps),
              let altitude = makeStatistics(values: window.map(\.relativeAltitude), timestamps: timestamps) else {
            return BarometerQualityResult(
                assessment: QualityAssessment(level: .low, warnings: [.insufficientSamples]),
                statistics: nil
            )
        }

        let pressureRange = (pressure.max ?? .infinity) - (pressure.min ?? 0)
        let altitudeRange = (altitude.max ?? .infinity) - (altitude.min ?? 0)
        var warnings: [QualityWarning] = []
        if pressureRange > configuration.barometerHighMaximumPressureRange {
            warnings.append(.pressureFluctuation)
        }
        if altitudeRange > configuration.barometerHighMaximumRelativeAltitudeRange {
            warnings.append(.altitudeDrift)
        }

        let level: QualityLevel
        if pressureRange <= configuration.barometerHighMaximumPressureRange,
           altitudeRange <= configuration.barometerHighMaximumRelativeAltitudeRange {
            level = .high
        } else if pressureRange <= configuration.barometerMediumMaximumPressureRange,
                  altitudeRange <= configuration.barometerMediumMaximumRelativeAltitudeRange {
            level = .medium
        } else {
            level = .low
        }
        return BarometerQualityResult(
            assessment: QualityAssessment(level: level, warnings: warnings),
            statistics: BarometerWindowStatistics(pressure: pressure, relativeAltitude: altitude)
        )
    }

    static func assessPedometer(
        status: ReadingStatus,
        isSupported: Bool,
        permission: MotionPermissionStatus,
        reading: PedometerReading?,
        waitingDuration: TimeInterval?,
        configuration: SensorQualityConfiguration = .default
    ) -> QualityAssessment {
        guard isSupported else {
            return QualityAssessment(level: .low, warnings: [.sensorUnavailable, .unavailablePedometer])
        }
        guard permission != .deniedRestricted else {
            return QualityAssessment(level: .low, warnings: [.permissionLimited, .unavailablePedometer])
        }
        if status == .waiting {
            let warning: QualityWarning = (waitingDuration ?? 0) >= configuration.pedometerWaitingTimeout ? .unavailablePedometer : .waitingForData
            return QualityAssessment(level: .low, warnings: [warning])
        }
        guard status == .available else {
            return unavailableAssessment(for: status, specificWarning: .unavailablePedometer)
        }
        guard let reading, reading.stepCount != nil else {
            return QualityAssessment(level: .low, warnings: [.missingRequiredData])
        }

        let hasAllOptionalFields = reading.distance != nil && reading.floorsAscended != nil && reading.floorsDescended != nil
        return QualityAssessment(
            level: hasAllOptionalFields ? .high : .medium,
            warnings: hasAllOptionalFields ? [] : [.missingPedometerOptionalFields]
        )
    }

    static func assessActivity(status: ReadingStatus, reading: ActivityReading?) -> QualityAssessment {
        guard status == .available else {
            return unavailableAssessment(for: status, specificWarning: .unavailableActivity)
        }
        guard let reading, let confidence = reading.confidence else {
            return QualityAssessment(level: .low, warnings: [.missingRequiredData, .unavailableActivity])
        }
        switch confidence {
        case .high:
            return QualityAssessment(level: .high)
        case .medium:
            return QualityAssessment(level: .medium)
        case .low:
            return QualityAssessment(level: .low, warnings: [.lowActivityConfidence])
        }
    }

    static func makeStatistics(values: [Double], timestamps: [TimeInterval]) -> SampleWindowStatistics? {
        guard !values.isEmpty, values.count == timestamps.count else { return nil }
        let count = values.count
        let mean = values.reduce(0, +) / Double(count)
        let variance = values.reduce(0) { partial, value in
            let difference = value - mean
            return partial + difference * difference
        } / Double(count)
        let rate: Double? = {
            guard count > 1, let first = timestamps.first, let last = timestamps.last, last > first else { return nil }
            return Double(count - 1) / (last - first)
        }()
        return SampleWindowStatistics(
            sampleCount: count,
            actualSampleRate: rate,
            min: values.min(),
            max: values.max(),
            mean: mean,
            standardDeviation: sqrt(variance)
        )
    }

    static func exponentialMovingAverage(previous: Double?, current: Double, alpha: Double) -> Double {
        guard let previous else { return current }
        let clampedAlpha = min(max(alpha, 0), 1)
        return clampedAlpha * current + (1 - clampedAlpha) * previous
    }

    static func displayValue(_ value: Double?, zeroThreshold: Double) -> Double? {
        guard let value else { return nil }
        return abs(value) < zeroThreshold ? 0 : value
    }

    private static func unavailableAssessment(
        for status: ReadingStatus,
        specificWarning: QualityWarning
    ) -> QualityAssessment {
        let warnings: [QualityWarning]
        switch status {
        case .waiting:
            warnings = [.waitingForData]
        case .available:
            warnings = [.missingRequiredData]
        case .unavailable:
            warnings = [.sensorUnavailable, specificWarning]
        case .denied:
            warnings = [.permissionLimited, specificWarning]
        case .error:
            warnings = [.sensorError, specificWarning]
        }
        return QualityAssessment(level: .low, warnings: warnings)
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
