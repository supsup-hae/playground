import CoreLocation
import FlutterMacOS

/// Dart `geocoder.dart` 의 좌표를 한국어 주소 칸으로 바꾼다 (CLGeocoder).
///
/// - `reverse({latitude, longitude})`: `{country, admin, locality, subLocality, thoroughfare}`
///   (없는 칸은 빠짐) 또는 결과가 없으면 nil. 네트워크 오류·호출 제한은 `network` 오류
enum GeocoderChannel {
  /// CLGeocoder 는 한 번에 요청 하나만 처리한다. Dart 쪽이 차례로 부른다.
  private static let geocoder = CLGeocoder()

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "recipe_slot_manager/geocoder", binaryMessenger: registrar.messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "reverse" else {
        return result(FlutterMethodNotImplemented)
      }
      guard let args = call.arguments as? [String: Any],
        let latitude = args["latitude"] as? Double,
        let longitude = args["longitude"] as? Double
      else {
        return result(FlutterError(code: "arguments", message: "좌표가 없다", details: nil))
      }
      geocoder.reverseGeocodeLocation(
        CLLocation(latitude: latitude, longitude: longitude),
        preferredLocale: Locale(identifier: "ko_KR")
      ) { placemarks, error in
        if let error = error as? CLError {
          switch error.code {
          case .geocodeFoundNoResult:
            result(nil)
          case .network:
            // 호출 제한도 network 로 온다.
            result(FlutterError(code: "network", message: error.localizedDescription, details: nil))
          default:
            result(FlutterError(code: "geocode", message: error.localizedDescription, details: nil))
          }
          return
        }
        guard let place = placemarks?.first else { return result(nil) }
        let fields: [String: String?] = [
          "country": place.country,
          "admin": place.administrativeArea,
          "locality": place.locality,
          "subLocality": place.subLocality,
          "thoroughfare": place.thoroughfare,
        ]
        result(fields.compactMapValues { $0 })
      }
    }
  }
}
