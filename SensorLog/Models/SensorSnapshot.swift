import Foundation
import SwiftData

@Model
final class SensorSnapshot: Identifiable {
    var id: UUID
    var createdAt: Date

    var latitude: Double?
    var longitude: Double?
    var horizontalAccuracy: Double?
    var verticalAccuracy: Double?
    var speed: Double?
    var speedAccuracy: Double?
    var altitude: Double?
    var course: Double?
    var courseAccuracy: Double?
    var lastUpdatedAt: Date?

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

    var relativeAltitude: Double?
    var pressure: Double?

    var stepCount: Int?
    var distance: Double?
    var floorsAscended: Int?
    var floorsDescended: Int?

    var activityType: String?
    var activityConfidence: String?

    var batteryLevel: Double?
    var batteryState: String?
    var isLowPowerModeEnabled: Bool?
    var thermalState: String?

    // V2 analysis fields remain optional so stores created by v1 can migrate.
    var qualitySchemaVersion: Int?
    var locationQualityJSON: String?
    var motionQualityJSON: String?
    var barometerQualityJSON: String?
    var pedometerQualityJSON: String?
    var activityQualityJSON: String?
    var isMotionStationary: Bool?
    var smoothingModeRawValue: String?
    var motionWindowStatisticsJSON: String?
    var barometerWindowStatisticsJSON: String?

    init(id: UUID = UUID(), createdAt: Date = .now, liveState: LiveSensorState) {
        self.id = id
        self.createdAt = createdAt

        let location = liveState.locationStatus == .available ? liveState.location : nil
        let motion = liveState.motionStatus == .available ? liveState.motion : nil
        let barometer = liveState.barometerStatus == .available ? liveState.barometer : nil
        let pedometer = liveState.pedometerStatus == .available ? liveState.pedometer : nil
        let activity = liveState.activityStatus == .available ? liveState.activity : nil
        let device = liveState.deviceStatus == .available ? liveState.device : nil

        latitude = location?.latitude
        longitude = location?.longitude
        horizontalAccuracy = location?.horizontalAccuracy
        verticalAccuracy = location?.verticalAccuracy
        speed = location?.speed
        speedAccuracy = location?.speedAccuracy
        altitude = location?.altitude
        course = location?.course
        courseAccuracy = location?.courseAccuracy
        lastUpdatedAt = location?.lastUpdatedAt

        userAccelerationX = motion?.userAccelerationX
        userAccelerationY = motion?.userAccelerationY
        userAccelerationZ = motion?.userAccelerationZ
        gravityX = motion?.gravityX
        gravityY = motion?.gravityY
        gravityZ = motion?.gravityZ
        rotationRateX = motion?.rotationRateX
        rotationRateY = motion?.rotationRateY
        rotationRateZ = motion?.rotationRateZ
        roll = motion?.roll
        pitch = motion?.pitch
        yaw = motion?.yaw

        relativeAltitude = barometer?.relativeAltitude
        pressure = barometer?.pressure

        stepCount = pedometer?.stepCount
        distance = pedometer?.distance
        floorsAscended = pedometer?.floorsAscended
        floorsDescended = pedometer?.floorsDescended

        activityType = activity?.type?.rawValue
        activityConfidence = activity?.confidence?.rawValue

        batteryLevel = device?.batteryLevel
        batteryState = device?.batteryState.rawValue
        isLowPowerModeEnabled = device?.isLowPowerModeEnabled
        thermalState = device?.thermalState.rawValue

        qualitySchemaVersion = 2
        locationQualityJSON = SnapshotV2JSONCodec.encode(liveState.locationQuality)
        motionQualityJSON = SnapshotV2JSONCodec.encode(liveState.motionQuality)
        barometerQualityJSON = SnapshotV2JSONCodec.encode(liveState.barometerQuality)
        pedometerQualityJSON = SnapshotV2JSONCodec.encode(liveState.pedometerQuality)
        activityQualityJSON = SnapshotV2JSONCodec.encode(liveState.activityQuality)
        isMotionStationary = liveState.isMotionStationary
        smoothingModeRawValue = liveState.smoothingMode.rawValue
        motionWindowStatisticsJSON = liveState.motionWindowStatistics.flatMap { SnapshotV2JSONCodec.encode($0) }
        barometerWindowStatisticsJSON = liveState.barometerWindowStatistics.flatMap { SnapshotV2JSONCodec.encode($0) }
    }

    var hasLocationData: Bool {
        latitude != nil ||
            longitude != nil ||
            horizontalAccuracy != nil ||
            verticalAccuracy != nil ||
            speed != nil ||
            speedAccuracy != nil ||
            altitude != nil ||
            course != nil ||
            courseAccuracy != nil ||
            lastUpdatedAt != nil
    }

    var hasMotionData: Bool {
        userAccelerationX != nil || userAccelerationY != nil || userAccelerationZ != nil || gravityX != nil || gravityY != nil || gravityZ != nil || rotationRateX != nil || rotationRateY != nil || rotationRateZ != nil || roll != nil || pitch != nil || yaw != nil
    }

    var hasBarometerData: Bool {
        relativeAltitude != nil || pressure != nil
    }

    var hasPedometerData: Bool {
        stepCount != nil || distance != nil || floorsAscended != nil || floorsDescended != nil
    }

    var hasActivityData: Bool {
        activityType != nil || activityConfidence != nil
    }

    var hasDeviceData: Bool {
        batteryLevel != nil || batteryState != nil || isLowPowerModeEnabled != nil || thermalState != nil
    }

    var hasQualityAnalysis: Bool {
        qualitySchemaVersion != nil ||
            locationQualityJSON != nil ||
            motionQualityJSON != nil ||
            barometerQualityJSON != nil ||
            pedometerQualityJSON != nil ||
            activityQualityJSON != nil ||
            isMotionStationary != nil ||
            smoothingModeRawValue != nil ||
            motionWindowStatisticsJSON != nil ||
            barometerWindowStatisticsJSON != nil
    }

    var savedLocationQuality: QualityAssessment? {
        SnapshotV2JSONCodec.decode(QualityAssessment.self, from: locationQualityJSON)
    }

    var savedMotionQuality: QualityAssessment? {
        SnapshotV2JSONCodec.decode(QualityAssessment.self, from: motionQualityJSON)
    }

    var savedBarometerQuality: QualityAssessment? {
        SnapshotV2JSONCodec.decode(QualityAssessment.self, from: barometerQualityJSON)
    }

    var savedPedometerQuality: QualityAssessment? {
        SnapshotV2JSONCodec.decode(QualityAssessment.self, from: pedometerQualityJSON)
    }

    var savedActivityQuality: QualityAssessment? {
        SnapshotV2JSONCodec.decode(QualityAssessment.self, from: activityQualityJSON)
    }

    var savedSmoothingMode: SmoothingMode? {
        guard let smoothingModeRawValue else { return nil }
        return SmoothingMode(rawValue: smoothingModeRawValue)
    }

    var savedMotionWindowStatistics: MotionWindowStatistics? {
        SnapshotV2JSONCodec.decode(MotionWindowStatistics.self, from: motionWindowStatisticsJSON)
    }

    var savedBarometerWindowStatistics: BarometerWindowStatistics? {
        SnapshotV2JSONCodec.decode(BarometerWindowStatistics.self, from: barometerWindowStatisticsJSON)
    }

    var savedWarningIdentifiers: [String] {
        let assessments = [
            savedLocationQuality,
            savedMotionQuality,
            savedBarometerQuality,
            savedPedometerQuality,
            savedActivityQuality
        ]
        let identifiers = assessments
            .compactMap { $0 }
            .flatMap(\.warnings)
            .map(\.rawValue)
        return Array(Set(identifiers)).sorted()
    }
}

enum SnapshotRetentionPolicy {
    static let limit = 500

    @MainActor
    static func pruneOldestSnapshots(in modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<SensorSnapshot>(
            sortBy: [SortDescriptor(\SensorSnapshot.createdAt, order: .forward)]
        )
        let snapshots = try modelContext.fetch(descriptor)
        let overflow = snapshots.count - limit
        guard overflow > 0 else { return }

        for snapshot in snapshots.prefix(overflow) {
            modelContext.delete(snapshot)
        }
        try modelContext.save()
    }
}

private enum SnapshotV2JSONCodec {
    static func encode<Value: Encodable>(_ value: Value) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode<Value: Decodable>(_ type: Value.Type, from string: String?) -> Value? {
        guard let string, let data = string.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }
}
