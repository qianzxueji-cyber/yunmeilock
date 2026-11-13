import Foundation
import CoreLocation

final class LocationProvider: NSObject,CLLocationManagerDelegate {
    private let manager=CLLocationManager()
    private var continuation:CheckedContinuation<(lat:Double,lng:Double),Error>?
    private var timeout:DispatchWorkItem?
    private var requesting=false
    override init() {
        super.init()
        manager.delegate=self; manager.desiredAccuracy=kCLLocationAccuracyBest
    }
    @MainActor func requestOnce() async throws -> (lat:Double,lng:Double) {
        try Task.checkCancellation()
        return try await withTaskCancellationHandler(operation:{
            try await withCheckedThrowingContinuation { pending in
                guard continuation == nil,CLLocationManager.locationServicesEnabled() else { pending.resume(throwing:AppError.message("定位服务不可用")); return }
                continuation=pending
                let work=DispatchWorkItem { [weak self] in self?.finish(.failure(AppError.message("定位服务不可用"))) }
                timeout=work; DispatchQueue.main.asyncAfter(deadline:.now()+20,execute:work)
                authorize()
            }
        },onCancel:{
            DispatchQueue.main.async { [weak self] in self?.finish(.failure(CancellationError())) }
        })
    }
    private func authorize() {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways,.authorizedWhenInUse:
            if !requesting { requesting=true; manager.requestLocation() }
        case .denied,.restricted: finish(.failure(AppError.message("您拒绝了权限请求")))
        @unknown default: finish(.failure(AppError.message("定位服务不可用")))
        }
    }
    private func finish(_ result:Result<(lat:Double,lng:Double),Error>) {
        timeout?.cancel(); timeout=nil; requesting=false
        let pending=continuation; continuation=nil
        manager.stopUpdatingLocation(); pending?.resume(with:result)
    }
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager) { authorize() }
    func locationManager(_ manager:CLLocationManager,didUpdateLocations locations:[CLLocation]) {
        guard let location=locations.last,location.horizontalAccuracy>=0,abs(location.timestamp.timeIntervalSinceNow)<30,CLLocationCoordinate2DIsValid(location.coordinate) else { return }
        finish(.success((location.coordinate.latitude,location.coordinate.longitude)))
    }
    func locationManager(_ manager:CLLocationManager,didFailWithError error:Error) {
        finish(.failure(AppError.message("定位服务不可用")))
    }
}
