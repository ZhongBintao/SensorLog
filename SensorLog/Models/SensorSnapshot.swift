import Foundation
import SwiftData

@Model
final class SensorSnapshot: Identifiable {
    var id: UUID
    var createdAt: Date

    var latitude: Double?
    var longitude: Double?
    var horizontalAccuracy: Double?
    var speed: Double?
    var altitude: Double?
    var course: Double?

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

    init(id: UUID = UUID(), createdAt: Date = .now, liveState: LiveSensorState) {
        self.id = id
        self.createdAt = createdAt

        latitude = liveState.location?.latitude
        longitude = liveState.location?.longitude
        horizontalAccuracy = liveState.location?.horizontalAccuracy
        speed = liveState.location?.speed
        altitude = liveState.location?.altitude
        course = liveState.location?.course

        userAccelerationX = liveState.motion?.userAccelerationX
        userAccelerationY = liveState.motion?.userAccelerationY
        userAccelerationZ = liveState.motion?.userAccelerationZ
        gravityX = liveState.motion?.gravityX
        gravityY = liveState.motion?.gravityY
        gravityZ = liveState.motion?.gravityZ
        rotationRateX = liveState.motion?.rotationRateX
        rotationRateY = liveState.motion?.rotationRateY
        rotationRateZ = liveState.motion?.rotationRateZ
        roll = liveState.motion?.roll
        pitch = liveState.motion?.pitch
        yaw = liveState.motion?.yaw

        relativeAltitude = liveState.barometer?.relativeAltitude
        pressure = liveState.barometer?.pressure

        stepCount = liveState.pedometer?.stepCount
        distance = liveState.pedometer?.distance
        floorsAscended = liveState.pedometer?.floorsAscended
        floorsDescended = liveState.pedometer?.floorsDescended

        activityType = liveState.activity?.type?.rawValue
        activityConfidence = liveState.activity?.confidence?.rawValue

        batteryLevel = liveState.device.batteryLevel
        batteryState = liveState.device.batteryState.rawValue
        isLowPowerModeEnabled = liveState.device.isLowPowerModeEnabled
        thermalState = liveState.device.thermalState.rawValue
    }

    var hasLocationData: Bool {
        latitude != nil || longitude != nil || horizontalAccuracy != nil || speed != nil || altitude != nil || course != nil
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
}
