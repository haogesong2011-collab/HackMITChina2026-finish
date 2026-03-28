//
//  LocationManager.swift
//  bicycle app
//
//  Created by Haoge on 2026/3/27.
//

import CoreLocation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var userLocation: CLLocationCoordinate2D?
    var userLocationAccuracy: CLLocationAccuracy = .greatestFiniteMagnitude
    var userLocationToken: UInt = 0

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        authorizationStatus = manager.authorizationStatus
        manager.requestWhenInUseAuthorization()
        // 若用户此前已授权，系统往往不会再触发 didChangeAuthorization，必须主动开始更新。
        startUpdatesIfAuthorized()
    }

    /// 在已获定位权限时开启连续定位；地图导航依赖此处，否则 `userLocation` 会卡在首次或搜索时的点。
    func startUpdatesIfAuthorized() {
        authorizationStatus = manager.authorizationStatus
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        manager.startUpdatingLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coord = location.coordinate
        let accuracy = location.horizontalAccuracy
        Task { @MainActor in
            self.userLocation = coord
            self.userLocationAccuracy = accuracy
            self.userLocationToken &+= 1
        }
    }
}
