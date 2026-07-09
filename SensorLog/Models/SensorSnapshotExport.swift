import Foundation
import UIKit

extension SensorSnapshot {
    func exportJSONString() throws -> String {
        let payload = SnapshotExportPayload(snapshot: self)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(payload)
        return String(decoding: data, as: UTF8.self)
    }
}

private struct SnapshotExportPayload: Codable {
    var schemaVersion = 1
    var app = "SensorLog"
    var createdAt: Date
    var device: SnapshotDeviceMetadata
    var readings: SnapshotReadings

    init(snapshot: SensorSnapshot) {
        createdAt = snapshot.createdAt
        device = SnapshotDeviceMetadata.current
        readings = SnapshotReadings(snapshot: snapshot)
    }
}

private struct SnapshotDeviceMetadata: Codable {
    var model: String
    var systemName: String
    var systemVersion: String

    static var current: SnapshotDeviceMetadata {
        let device = UIDevice.current
        return SnapshotDeviceMetadata(
            model: device.model,
            systemName: device.systemName,
            systemVersion: device.systemVersion
        )
    }
}

private struct SnapshotReadings: Codable {
    var location: SnapshotLocationReading
    var motion: SnapshotMotionReading
    var barometer: SnapshotBarometerReading
    var pedometer: SnapshotPedometerReading
    var activity: SnapshotActivityReading
    var device: SnapshotDeviceReading

    init(snapshot: SensorSnapshot) {
        location = SnapshotLocationReading(snapshot: snapshot)
        motion = SnapshotMotionReading(snapshot: snapshot)
        barometer = SnapshotBarometerReading(snapshot: snapshot)
        pedometer = SnapshotPedometerReading(snapshot: snapshot)
        activity = SnapshotActivityReading(snapshot: snapshot)
        device = SnapshotDeviceReading(snapshot: snapshot)
    }
}

private struct SnapshotLocationReading: Codable {
    var latitude: Double?
    var longitude: Double?
    var horizontalAccuracy: Double?
    var speed: Double?
    var altitude: Double?
    var course: Double?

    init(snapshot: SensorSnapshot) {
        latitude = snapshot.latitude
        longitude = snapshot.longitude
        horizontalAccuracy = snapshot.horizontalAccuracy
        speed = snapshot.speed
        altitude = snapshot.altitude
        course = snapshot.course
    }
}

private struct SnapshotMotionReading: Codable {
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

    init(snapshot: SensorSnapshot) {
        userAccelerationX = snapshot.userAccelerationX
        userAccelerationY = snapshot.userAccelerationY
        userAccelerationZ = snapshot.userAccelerationZ
        gravityX = snapshot.gravityX
        gravityY = snapshot.gravityY
        gravityZ = snapshot.gravityZ
        rotationRateX = snapshot.rotationRateX
        rotationRateY = snapshot.rotationRateY
        rotationRateZ = snapshot.rotationRateZ
        roll = snapshot.roll
        pitch = snapshot.pitch
        yaw = snapshot.yaw
    }
}

private struct SnapshotBarometerReading: Codable {
    var relativeAltitude: Double?
    var pressure: Double?

    init(snapshot: SensorSnapshot) {
        relativeAltitude = snapshot.relativeAltitude
        pressure = snapshot.pressure
    }
}

private struct SnapshotPedometerReading: Codable {
    var stepCount: Int?
    var distance: Double?
    var floorsAscended: Int?
    var floorsDescended: Int?

    init(snapshot: SensorSnapshot) {
        stepCount = snapshot.stepCount
        distance = snapshot.distance
        floorsAscended = snapshot.floorsAscended
        floorsDescended = snapshot.floorsDescended
    }
}

private struct SnapshotActivityReading: Codable {
    var activityType: String?
    var activityConfidence: String?

    init(snapshot: SensorSnapshot) {
        activityType = snapshot.activityType
        activityConfidence = snapshot.activityConfidence
    }
}

private struct SnapshotDeviceReading: Codable {
    var batteryLevel: Double?
    var batteryState: String?
    var isLowPowerModeEnabled: Bool?
    var thermalState: String?

    init(snapshot: SensorSnapshot) {
        batteryLevel = snapshot.batteryLevel
        batteryState = snapshot.batteryState
        isLowPowerModeEnabled = snapshot.isLowPowerModeEnabled
        thermalState = snapshot.thermalState
    }
}
