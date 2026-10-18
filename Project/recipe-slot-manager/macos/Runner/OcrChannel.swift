import FlutterMacOS
import ImageIO
import Vision

/// Dart `recognizeText` 가 보낸 이미지 바이트에서 글자를 줄 단위로 읽는다 (Vision).
/// 인식은 백그라운드 큐에서 하고 결과는 메인 큐에서 돌려준다.
enum OcrChannel {
  private static let maxSide = 4096

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "recipe_slot_manager/ocr", binaryMessenger: registrar.messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognize" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let data = (call.arguments as? FlutterStandardTypedData)?.data else {
        result(FlutterError(code: "arguments", message: "이미지 바이트가 없다", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        let reply = recognize(data)
        DispatchQueue.main.async { result(reply) }
      }
    }
  }

  private static func recognize(_ data: Data) -> Any {
    // 긴 변을 maxSide 이하로 줄여 읽는다. 사진을 잘못 골라도 메모리가 크게 늘지 않는다.
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxSide,
    ]
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else {
      return FlutterError(code: "image", message: "이미지를 열지 못했다", details: nil)
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["ko-KR", "en-US"]
    do {
      try VNImageRequestHandler(cgImage: image).perform([request])
    } catch {
      return FlutterError(code: "ocr", message: error.localizedDescription, details: nil)
    }
    // Vision 좌표는 왼쪽 아래가 원점이다. 위에서 아래, 왼쪽에서 오른쪽 순서로 돌려준다.
    let lines = (request.results ?? []).sorted {
      $0.boundingBox.midY == $1.boundingBox.midY
        ? $0.boundingBox.minX < $1.boundingBox.minX
        : $0.boundingBox.midY > $1.boundingBox.midY
    }
    return lines.compactMap { $0.topCandidates(1).first?.string }
  }
}
