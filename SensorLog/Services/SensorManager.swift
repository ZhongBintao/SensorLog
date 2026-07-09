import CoreLocation
import CoreMotion
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class SensorManager {
    var liveState = LiveSensorState()
    var permissions = SensorPermissionState()
    var availability = SensorAvailability()
    var lastErrorMessage: String?

    @ObservationIgnored private lazy var locationDelegate = LocationDelegate(owner: self)
    @ObservationIgnored private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = locationDelegate
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        return manager
    }()

    @ObservationIgnored private let motionManager = CMMotionManager()
    @ObservationIgnored private let altimeter = CMAltimeter()
    @ObservationIgnored private let pedometer = CMPedometer()
    @ObservationIgnored private let activityManager = CMMotionActivityManager()
    @ObservationIgnored private let sensorQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "SensorLog.SensorQueue"
        queue.qualityOfService = .userInitiated
        return queue
    }()

    @ObservationIgnored private var displayTimer: Timer?
    @ObservationIgnored private var latestMotion: CMDeviceMotion?
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var isUpdatingLocation = false
    @ObservationIgnored private var isUpdatingMotion = false
    @ObservationIgnored private var isUpdatingAltimeter = false
    @ObservationIgnored private var isUpdatingPedometer = false
    @ObservationIgnored private var isUpdatingActivity = false

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refreshPermissions()
        refreshAvailability()
        refreshDeviceState()
    }

    deinit {
        displayTimer?.invalidate()
        motionManager.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
        pedometer.stopUpdates()
        activityManager.stopActivityUpdates()
    }

    func start() {
        refreshPermissions()
        refreshAvailability()
        refreshDeviceState()

        guard !hasStarted else {
            startLocationIfAllowed()
            return
        }

        hasStarted = true
        startLocationIfAllowed()
        startMotion()
        startAltimeter()
        startPedometer()
        startActivity()
        startDisplayTimer()
    }

    func requestLocationPermission() {
        _ = locationManager
        locationManager.requestWhenInUseAuthorization()
    }

    func requestMotionPermission() {
        refreshMotionPermission()
        startPedometer()
        startActivity()
    }

    func refreshPermissions() {
        permissions.location = mapLocationAuthorization(locationManager.authorizationStatus)
        refreshMotionPermission()
    }

    func refreshAvailability() {
        availability = SensorAvailability(
            deviceMotion: motionManager.isDeviceMotionAvailable,
            gyroscope: motionManager.isGyroAvailable,
            accelerometer: motionManager.isAccelerometerAvailable,
            barometer: CMAltimeter.isRelativeAltitudeAvailable(),
            pedometer: CMPedometer.isStepCountingAvailable(),
            activityRecognition: CMMotionActivityManager.isActivityAvailable()
        )
    }

    private func refreshMotionPermission() {
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized:
            permissions.motion = .available
        case .denied, .restricted:
            permissions.motion = .deniedRestricted
        case .notDetermined:
            permissions.motion = .unknown
        @unknown default:
            permissions.motion = .unknown
        }
    }

    private func startLocationIfAllowed() {
        let status = locationManager.authorizationStatus
        permissions.location = mapLocationAuthorization(status)

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if liveState.location == nil {
                liveState.locationStatus = .waiting
            }
            guard !isUpdatingLocation else { return }
            isUpdatingLocation = true
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            liveState.locationStatus = .denied
            isUpdatingLocation = false
            locationManager.stopUpdatingLocation()
        case .notDetermined:
            liveState.locationStatus = .waiting
        @unknown default:
            liveState.locationStatus = .error
        }
    }

    private func startMotion() {
        guard !isUpdatingMotion else { return }
        guard motionManager.isDeviceMotionAvailable else {
            liveState.motionStatus = .unavailable
            return
        }

        isUpdatingMotion = true
        liveState.motionStatus = .waiting
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0
        motionManager.startDeviceMotionUpdates(to: sensorQueue) { [weak self] motion, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.liveState.motionStatus = .error
                    self.lastErrorMessage = error.localizedDescription
                    return
                }
                self.latestMotion = motion
            }
        }
    }

    private func startAltimeter() {
        guard !isUpdatingAltimeter else { return }
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            liveState.barometerStatus = .unavailable
            return
        }

        isUpdatingAltimeter = true
        liveState.barometerStatus = .waiting
        altimeter.startRelativeAltitudeUpdates(to: sensorQueue) { [weak self] data, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.liveState.barometerStatus = .error
                    self.lastErrorMessage = error.localizedDescription
                    return
                }
                guard let data else { return }
                self.liveState.barometer = BarometerReading(
                    relativeAltitude: data.relativeAltitude.doubleValue,
                    pressure: data.pressure.doubleValue * 10.0
                )
                self.liveState.barometerStatus = .available
            }
        }
    }

    private func startPedometer() {
        guard !isUpdatingPedometer else { return }
        guard CMPedometer.isStepCountingAvailable() else {
            liveState.pedometerStatus = .unavailable
            return
        }

        isUpdatingPedometer = true
        liveState.pedometerStatus = .waiting
        let startOfDay = Calendar.current.startOfDay(for: Date())
        pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.handleMotionRelatedError(error, group: .pedometer)
                    return
                }
                guard let data else { return }
                self.liveState.pedometer = PedometerReading(
                    stepCount: data.numberOfSteps.intValue,
                    distance: data.distance?.doubleValue,
                    floorsAscended: data.floorsAscended?.intValue,
                    floorsDescended: data.floorsDescended?.intValue
                )
                self.liveState.pedometerStatus = .available
                self.refreshMotionPermission()
            }
        }
    }

    private func startActivity() {
        guard !isUpdatingActivity else { return }
        guard CMMotionActivityManager.isActivityAvailable() else {
            liveState.activityStatus = .unavailable
            return
        }

        isUpdatingActivity = true
        liveState.activityStatus = .waiting
        activityManager.startActivityUpdates(to: sensorQueue) { [weak self] activity in
            Task { @MainActor in
                guard let self else { return }
                guard let activity else { return }
                self.liveState.activity = ActivityReading(
                    type: Self.activityType(from: activity),
                    confidence: Self.activityConfidence(from: activity.confidence)
                )
                self.liveState.activityStatus = .available
                self.refreshMotionPermission()
            }
        }
    }

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.publishLatestMotion()
                self?.refreshDeviceState()
            }
        }
    }

    private func publishLatestMotion() {
        guard let motion = latestMotion else { return }
        liveState.motion = MotionReading(
            userAccelerationX: motion.userAcceleration.x,
            userAccelerationY: motion.userAcceleration.y,
            userAccelerationZ: motion.userAcceleration.z,
            gravityX: motion.gravity.x,
            gravityY: motion.gravity.y,
            gravityZ: motion.gravity.z,
            rotationRateX: motion.rotationRate.x,
            rotationRateY: motion.rotationRate.y,
            rotationRateZ: motion.rotationRate.z,
            roll: motion.attitude.roll,
            pitch: motion.attitude.pitch,
            yaw: motion.attitude.yaw
        )
        liveState.motionStatus = .available
    }

    private func refreshDeviceState() {
        let batteryLevel = UIDevice.current.batteryLevel
        liveState.device = DeviceReading(
            batteryLevel: batteryLevel >= 0 ? Double(batteryLevel) * 100.0 : nil,
            batteryState: Self.batteryState(from: UIDevice.current.batteryState),
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalState: Self.thermalState(from: ProcessInfo.processInfo.thermalState)
        )
        liveState.deviceStatus = .available
    }

    private func handle(location: CLLocation) {
        liveState.location = LocationReading(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil,
            speed: location.speed >= 0 ? location.speed : nil,
            altitude: location.verticalAccuracy >= 0 ? location.altitude : nil,
            course: location.course >= 0 ? location.course : nil
        )
        liveState.locationStatus = .available
    }

    private func handleLocationError(_ error: Error) {
        let clError = error as? CLError
        if clError?.code == .denied {
            liveState.locationStatus = .denied
            permissions.location = .denied
        } else {
            liveState.locationStatus = .error
        }
        lastErrorMessage = error.localizedDescription
    }

    private func handleLocationAuthorizationChange(_ status: CLAuthorizationStatus) {
        permissions.location = mapLocationAuthorization(status)
        startLocationIfAllowed()
    }

    private func handleMotionRelatedError(_ error: Error, group: MotionGroup) {
        refreshMotionPermission()
        let status: ReadingStatus = permissions.motion == .deniedRestricted ? .denied : .error
        switch group {
        case .pedometer:
            liveState.pedometerStatus = status
        case .activity:
            liveState.activityStatus = status
        }
        lastErrorMessage = error.localizedDescription
    }

    private func mapLocationAuthorization(_ status: CLAuthorizationStatus) -> LocationPermissionStatus {
        switch status {
        case .notDetermined:
            .notDetermined
        case .restricted:
            .restricted
        case .denied:
            .denied
        case .authorizedAlways, .authorizedWhenInUse:
            .authorizedWhenInUse
        @unknown default:
            .notDetermined
        }
    }

    private enum MotionGroup {
        case pedometer
        case activity
    }

    private final class LocationDelegate: NSObject, CLLocationManagerDelegate {
        weak var owner: SensorManager?

        init(owner: SensorManager) {
            self.owner = owner
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            Task { @MainActor [weak owner] in
                owner?.handleLocationAuthorizationChange(manager.authorizationStatus)
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            Task { @MainActor [weak owner] in
                owner?.handle(location: location)
            }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            Task { @MainActor [weak owner] in
                owner?.handleLocationError(error)
            }
        }
    }

    private static func activityType(from activity: CMMotionActivity) -> ActivityType {
        if activity.automotive { return .automotive }
        if activity.cycling { return .cycling }
        if activity.running { return .running }
        if activity.walking { return .walking }
        if activity.stationary { return .stationary }
        return .unknown
    }

    private static func activityConfidence(from confidence: CMMotionActivityConfidence) -> ActivityConfidence {
        switch confidence {
        case .low:
            .low
        case .medium:
            .medium
        case .high:
            .high
        @unknown default:
            .low
        }
    }

    private static func batteryState(from state: UIDevice.BatteryState) -> BatteryChargeState {
        switch state {
        case .unknown:
            .unknown
        case .unplugged:
            .unplugged
        case .charging:
            .charging
        case .full:
            .full
        @unknown default:
            .unknown
        }
    }

    private static func thermalState(from state: ProcessInfo.ThermalState) -> ThermalStateDisplay {
        switch state {
        case .nominal:
            .nominal
        case .fair:
            .fair
        case .serious:
            .serious
        case .critical:
            .critical
        @unknown default:
            .unknown
        }
    }
}

extension SensorManager {
    static var preview: SensorManager {
        let manager = SensorManager()
        manager.permissions = SensorPermissionState(location: .notDetermined, motion: .unknown)
        manager.availability = SensorAvailability(
            deviceMotion: true,
            gyroscope: true,
            accelerometer: true,
            barometer: true,
            pedometer: true,
            activityRecognition: true
        )
        manager.liveState = LiveSensorState(
            locationStatus: .waiting,
            motionStatus: .available,
            barometerStatus: .available,
            pedometerStatus: .waiting,
            activityStatus: .available,
            deviceStatus: .available,
            location: nil,
            motion: MotionReading(
                userAccelerationX: 0.01,
                userAccelerationY: -0.02,
                userAccelerationZ: 0.03,
                gravityX: 0.00,
                gravityY: -0.01,
                gravityZ: -0.99,
                rotationRateX: 0.02,
                rotationRateY: 0.01,
                rotationRateZ: -0.01,
                roll: 0.02,
                pitch: -0.01,
                yaw: 1.18
            ),
            barometer: BarometerReading(relativeAltitude: 1.4, pressure: 1012.8),
            pedometer: nil,
            activity: ActivityReading(type: .stationary, confidence: .high),
            device: DeviceReading(
                batteryLevel: 86,
                batteryState: .charging,
                isLowPowerModeEnabled: false,
                thermalState: .nominal
            )
        )
        return manager
    }
}
