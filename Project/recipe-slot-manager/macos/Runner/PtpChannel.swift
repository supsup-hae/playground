import FlutterMacOS
import ImageCaptureCore

/// Dart `MacosPtpTransport` 와 PTP 바이트를 주고받는다.
/// 명령 조립과 응답 해석은 Dart가 맡고, 여기서는 ImageCaptureCore 로 전달만 한다.
/// 상태는 모두 메인 큐에서만 바꾼다. ImageCaptureCore 완료 블록은 메인 큐로 옮긴 뒤 다룬다.
final class PtpChannel: NSObject {
  private static let fujifilmVendorID = 0x04CB
  private static let connectTimeout: TimeInterval = 10
  private static let sendTimeout: TimeInterval = 5

  private let browser = ICDeviceBrowser()
  private var camera: ICCameraDevice?
  private var isReady = false
  private var sendInFlight = false
  private var pendingConnect: FlutterResult?
  private var pendingConnectTimeout: DispatchWorkItem?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "recipe_slot_manager/ptp", binaryMessenger: registrar.messenger)
    let instance = PtpChannel()
    channel.setMethodCallHandler(instance.handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "connect": connect(result)
    case "send": send(call.arguments, result)
    case "disconnect": disconnect(result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - connect

  private func connect(_ result: @escaping FlutterResult) {
    if let camera, isReady {
      result(camera.name ?? "Fujifilm")
      return
    }
    guard pendingConnect == nil else {
      result(FlutterError(code: "busy", message: "이미 연결 중이다", details: nil))
      return
    }
    pendingConnect = result
    let timeout = DispatchWorkItem { [weak self] in
      self?.failConnect("후지필름 카메라를 찾지 못했다. USB 연결과 PC 연결 모드를 확인할 것")
    }
    pendingConnectTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.connectTimeout, execute: timeout)

    browser.delegate = self
    browser.browsedDeviceTypeMask = ICDeviceTypeMask(
      rawValue: ICDeviceTypeMask.camera.rawValue | ICDeviceLocationTypeMask.local.rawValue)!
    browser.start()
  }

  /// 대기 중인 connect 에 결과를 한 번만 돌려주고 그 연결의 시간 제한을 취소한다.
  private func completeConnect(_ value: Any) {
    pendingConnectTimeout?.cancel()
    pendingConnectTimeout = nil
    guard let result = pendingConnect else { return }
    pendingConnect = nil
    result(value)
  }

  /// 세션을 정리하고, 대기 중인 connect 가 있으면 오류로 끝낸다.
  private func failConnect(_ message: String) {
    resetSession()
    completeConnect(FlutterError(code: "connect", message: message, details: nil))
  }

  private func resetSession() {
    browser.stop()
    camera?.requestCloseSession(options: nil) { _ in }
    camera = nil
    isReady = false
    sendInFlight = false
  }

  private func markReady(_ device: ICDevice) {
    guard let camera, device === camera, !isReady else { return }
    guard camera.capabilities.contains(ICDeviceCapability.cameraDeviceCanAcceptPTPCommands.rawValue)
    else {
      failConnect("이 카메라는 PTP 명령을 받지 않는다")
      return
    }
    isReady = true
    browser.stop()
    completeConnect(camera.name ?? "Fujifilm")
  }

  // MARK: - send

  private func send(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard let camera, isReady else {
      result(FlutterError(code: "disconnected", message: "카메라가 연결되지 않았다", details: nil))
      return
    }
    guard !sendInFlight else {
      result(FlutterError(code: "busy", message: "앞의 PTP 명령이 끝나지 않았다", details: nil))
      return
    }
    guard let args = arguments as? [String: Any],
      let command = args["command"] as? FlutterStandardTypedData
    else {
      result(FlutterError(code: "arguments", message: "command 가 없다", details: nil))
      return
    }
    let outData = (args["data"] as? FlutterStandardTypedData)?.data
    sendInFlight = true

    // 시간이 초과된 명령은 카메라 쪽에 남아 있을 수 있으므로 세션을 닫고 다시 연결하게 한다.
    var finished = false
    let timeout = DispatchWorkItem { [weak self] in
      guard !finished else { return }
      finished = true
      self?.resetSession()
      result(FlutterError(code: "timeout", message: "PTP 응답 시간 초과로 연결을 끊었다", details: nil))
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.sendTimeout, execute: timeout)

    camera.requestSendPTPCommand(command.data, outData: outData) { [weak self] data, response, error in
      DispatchQueue.main.async {
        guard !finished else { return }
        finished = true
        timeout.cancel()
        self?.sendInFlight = false
        if let error {
          result(FlutterError(code: "ptp", message: error.localizedDescription, details: nil))
          return
        }
        result([
          "response": FlutterStandardTypedData(bytes: response),
          "data": FlutterStandardTypedData(bytes: data),
        ])
      }
    }
  }

  // MARK: - disconnect

  private func disconnect(_ result: @escaping FlutterResult) {
    failConnect("연결을 끊었다")
    result(nil)
  }
}

extension PtpChannel: ICDeviceBrowserDelegate {
  func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
    // connect 를 기다리는 동안에만 카메라를 잡는다. 다시 꽂힌 카메라에 몰래 연결하지 않는다.
    guard pendingConnect != nil, camera == nil, let found = device as? ICCameraDevice,
      found.usbVendorID == Self.fujifilmVendorID
    else { return }
    camera = found
    found.delegate = self
    found.requestOpenSession(options: nil) { [weak self] error in
      guard let error else { return }
      DispatchQueue.main.async {
        guard let self, self.camera === found else { return }
        self.failConnect("세션을 열지 못했다: \(error.localizedDescription)")
      }
    }
  }

  func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
    didRemove(device)
  }
}

extension PtpChannel: ICCameraDeviceDelegate {
  func deviceDidBecomeReady(_ device: ICDevice) {
    markReady(device)
  }

  func deviceDidBecomeReady(withCompleteContentCatalog device: ICCameraDevice) {
    markReady(device)
  }

  func didRemove(_ device: ICDevice) {
    guard device === camera else { return }
    failConnect("카메라가 분리됐다")
  }

  func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {}
  func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {}
  func cameraDevice(_ camera: ICCameraDevice, didAdd items: [ICCameraItem]) {}
  func cameraDevice(_ camera: ICCameraDevice, didRemove items: [ICCameraItem]) {}
  func cameraDevice(
    _ camera: ICCameraDevice, didReceiveThumbnail thumbnail: CGImage?, for item: ICCameraItem,
    error: Error?
  ) {}
  func cameraDevice(
    _ camera: ICCameraDevice, didReceiveMetadata metadata: [AnyHashable: Any]?,
    for item: ICCameraItem, error: Error?
  ) {}
  func cameraDevice(_ camera: ICCameraDevice, didRenameItems items: [ICCameraItem]) {}
  func cameraDeviceDidChangeCapability(_ camera: ICCameraDevice) {}
  func cameraDevice(_ camera: ICCameraDevice, didReceivePTPEvent eventData: Data) {}
  func cameraDeviceDidRemoveAccessRestriction(_ device: ICDevice) {}
  func cameraDeviceDidEnableAccessRestriction(_ device: ICDevice) {}
}
