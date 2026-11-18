import Foundation

enum ReadingStatus: String, Codable {
    case waiting
    case available
    case unavailable
    case denied
    case error

    var titleKey: String {
        switch self {
        case .waiting: "Waiting Data"
        case .available: "Available"
        case .unavailable: "Unavailable"
        case .denied: "Permission Limited"
        case .error: "Error"
        }
    }
}

enum LocationPermissionStatus: String, Codable {
    case notDetermined
    case authorizedWhenInUse
    case denied
    case restricted

    var titleKey: String {
        switch self {
        case .notDetermined: "Not Determined"
        case .authorizedWhenInUse: "Authorized When In Use"
        case .denied: "Denied"
        case .restricted: "Restricted"
        }
    }
}

enum MotionPermissionStatus: String, Codable {
    case available
    case deniedRestricted
    case unknown

    var titleKey: String {
        switch self {
        case .available: "Available"
        case .deniedRestricted: "Denied or Restricted"
        case .unknown: "Unknown"
        }
    }
}

enum ActivityType: String, Codable {
    case stationary
    case walking
    case running
    case cycling
    case automotive
    case unknown

    var titleKey: String {
        switch self {
        case .stationary: "Stationary"
        case .walking: "Walking"
        case .running: "Running"
        case .cycling: "Cycling"
        case .automotive: "Automotive"
        case .unknown: "Unknown"
        }
    }
}

enum ActivityConfidence: String, Codable {
    case low
    case medium
    case high

    var titleKey: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

enum BatteryChargeState: String, Codable {
    case unknown
    case unplugged
    case charging
    case full

    var titleKey: String {
        switch self {
        case .unknown: "Unknown"
        case .unplugged: "Unplugged"
        case .charging: "Charging"
        case .full: "Full"
        }
    }
}

enum ThermalStateDisplay: String, Codable {
    case nominal
    case fair
    case serious
    case critical
    case unknown

    var titleKey: String {
        switch self {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        case .unknown: "Unknown"
        }
    }
}

struct LocationReading: Codable, Equatable {
    var latitude: Double?
    var longitude: Double?
    var horizontalAccuracy: Double?
    var verticalAccuracy: Double? = nil
    var speed: Double?
    var speedAccuracy: Double? = nil
    var altitude: Double?
    var course: Double?
    var courseAccuracy: Double? = nil
    var lastUpdatedAt: Date? = nil
}

struct MotionReading: Codable, Equatable {
    var userAccelerationX: Double?
    var userAccelerationY: Double?
    var userAccelerationZ: Double?
    var gravityX: Double?
    var gravityY: Double?
    var gravityZ: Double?
    var rotationRateX: Double?
    var rotationRateY: Double?
    var rotationRateZ: Double?
    var roll: Double?
    var pitch: Double?
    var yaw: Double?
}

struct BarometerReading: Codable, Equatable {
    var relativeAltitude: Double?
    var pressure: Double?
}

struct PedometerReading: Codable, Equatable {
    var stepCount: Int?
    var distance: Double?
    var floorsAscended: Int?
    var floorsDescended: Int?
}

struct ActivityReading: Codable, Equatable {
    var type: ActivityType?
    var confidence: ActivityConfidence?
}

struct DeviceReading: Codable, Equatable {
    var batteryLevel: Double?
    var batteryState: BatteryChargeState
    var isLowPowerModeEnabled: Bool
    var thermalState: ThermalStateDisplay
}

struct LiveSensorState: Codable, Equatable {
    var locationStatus: ReadingStatus = .waiting
    var motionStatus: ReadingStatus = .waiting
    var barometerStatus: ReadingStatus = .waiting
    var pedometerStatus: ReadingStatus = .waiting
    var activityStatus: ReadingStatus = .waiting
    var deviceStatus: ReadingStatus = .available

    var location: LocationReading?
    var motion: MotionReading?
    var smoothedMotion: MotionReading?
    var barometer: BarometerReading?
    var smoothedBarometer: BarometerReading?
    var pedometer: PedometerReading?
    var activity: ActivityReading?
    var device = DeviceReading(
        batteryLevel: nil,
        batteryState: .unknown,
        isLowPowerModeEnabled: false,
        thermalState: .unknown
    )

    var locationQuality = QualityAssessment(level: .low, confidence: nil, warnings: [.waitingForData])
    var motionQuality = QualityAssessment(level: .low, confidence: nil, warnings: [.waitingForData])
    var barometerQuality = QualityAssessment(level: .low, confidence: nil, warnings: [.waitingForData])
    var pedometerQuality = QualityAssessment(level: .low, confidence: nil, warnings: [.waitingForData])
    var activityQuality = QualityAssessment(level: .low, confidence: nil, warnings: [.waitingForData])
    var isMotionStationary: Bool?
    var smoothingMode: SmoothingMode = .raw
    var motionWindowStatistics: MotionWindowStatistics?
    var barometerWindowStatistics: BarometerWindowStatistics?
}

struct SensorPermissionState: Codable, Equatable {
    var location: LocationPermissionStatus = .notDetermined
    var motion: MotionPermissionStatus = .unknown
}

struct SensorAvailability: Codable, Equatable {
    var deviceMotion = false
    var gyroscope = false
    var accelerometer = false
    var barometer = false
    var pedometer = false
    var activityRecognition = false
}

struct SensorTrendSample: Identifiable, Equatable, Sendable {
    let id: UUID
    var timestamp: Date
    var rawValue: Double
    var smoothedValue: Double?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        rawValue: Double,
        smoothedValue: Double?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.rawValue = rawValue
        self.smoothedValue = smoothedValue
    }

    func value(for mode: SmoothingMode) -> Double {
        switch mode {
        case .raw:
            rawValue
        case .smoothed:
            smoothedValue ?? rawValue
        }
    }
}

struct SensorTrendState: Equatable, Sendable {
    var motionAcceleration: [SensorTrendSample] = []
    var locationAccuracy: [SensorTrendSample] = []
    var barometerPressure: [SensorTrendSample] = []
    var barometerAltitude: [SensorTrendSample] = []
}

enum SensorTrendBuffer {
    static let defaultDuration: TimeInterval = 60
    static let defaultMaximumCount = 600

    static func appending(
        _ sample: SensorTrendSample,
        to samples: [SensorTrendSample],
        duration: TimeInterval = defaultDuration,
        maximumCount: Int = defaultMaximumCount
    ) -> [SensorTrendSample] {
        var updatedSamples = samples
        if let lastTimestamp = updatedSamples.last?.timestamp,
           sample.timestamp < lastTimestamp {
            updatedSamples.removeAll(keepingCapacity: true)
        } else if updatedSamples.last?.timestamp == sample.timestamp {
            updatedSamples.removeLast()
        }

        updatedSamples.append(sample)
        return trimming(
            updatedSamples,
            referenceDate: sample.timestamp,
            duration: duration,
            maximumCount: maximumCount
        )
    }

    static func trimming(
        _ samples: [SensorTrendSample],
        referenceDate: Date,
        duration: TimeInterval = defaultDuration,
        maximumCount: Int = defaultMaximumCount
    ) -> [SensorTrendSample] {
        guard maximumCount > 0 else { return [] }
        let cutoff = referenceDate.addingTimeInterval(-duration)
        let recentSamples = samples.filter { $0.timestamp >= cutoff }
        return Array(recentSamples.suffix(maximumCount))
    }
}

extension MotionReading {
    var userAccelerationMagnitude: Double? {
        guard let userAccelerationX,
              let userAccelerationY,
              let userAccelerationZ else { return nil }
        return hypot(hypot(userAccelerationX, userAccelerationY), userAccelerationZ)
    }

    func applyingDisplayDeadband(
        configuration: SensorQualityConfiguration = .default
    ) -> MotionReading {
        MotionReading(
            userAccelerationX: SensorQualityAnalyzer.displayValue(userAccelerationX, zeroThreshold: configuration.accelerationDisplayZeroThreshold),
            userAccelerationY: SensorQualityAnalyzer.displayValue(userAccelerationY, zeroThreshold: configuration.accelerationDisplayZeroThreshold),
            userAccelerationZ: SensorQualityAnalyzer.displayValue(userAccelerationZ, zeroThreshold: configuration.accelerationDisplayZeroThreshold),
            gravityX: gravityX,
            gravityY: gravityY,
            gravityZ: gravityZ,
            rotationRateX: SensorQualityAnalyzer.displayValue(rotationRateX, zeroThreshold: configuration.rotationRateDisplayZeroThreshold),
            rotationRateY: SensorQualityAnalyzer.displayValue(rotationRateY, zeroThreshold: configuration.rotationRateDisplayZeroThreshold),
            rotationRateZ: SensorQualityAnalyzer.displayValue(rotationRateZ, zeroThreshold: configuration.rotationRateDisplayZeroThreshold),
            roll: roll,
            pitch: pitch,
            yaw: yaw
        )
    }
}
