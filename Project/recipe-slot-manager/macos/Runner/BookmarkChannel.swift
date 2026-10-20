import FlutterMacOS
import Foundation

/// 사용자가 고른 폴더를 다음 실행에서도 읽도록 보안 범위 북마크를 만들고 푼다 (Dart `folder_reader.dart`).
///
/// - `create(path)`: 북마크 바이트
/// - `resolve(bookmark)`: `{path, stale, bookmark?}`. 접근을 시작하고, 오래된 북마크면 새 북마크를 함께 준다
/// - `stop(path)`: `resolve` 로 시작한 접근을 닫는다
enum BookmarkChannel {
  private static var opened: [String: URL] = [:]

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "recipe_slot_manager/bookmarks", binaryMessenger: registrar.messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "create":
        guard let path = call.arguments as? String else {
          return result(FlutterError(code: "arguments", message: "경로가 없다", details: nil))
        }
        result(create(path))
      case "resolve":
        guard let data = (call.arguments as? FlutterStandardTypedData)?.data else {
          return result(FlutterError(code: "arguments", message: "북마크가 없다", details: nil))
        }
        result(resolve(data))
      case "stop":
        if let path = call.arguments as? String, let url = opened.removeValue(forKey: path) {
          url.stopAccessingSecurityScopedResource()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func create(_ path: String) -> Any {
    do {
      let data = try URL(fileURLWithPath: path).bookmarkData(
        options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
        includingResourceValuesForKeys: nil, relativeTo: nil)
      return FlutterStandardTypedData(bytes: data)
    } catch {
      return FlutterError(code: "bookmark", message: error.localizedDescription, details: nil)
    }
  }

  private static func resolve(_ data: Data) -> Any {
    do {
      var stale = false
      let url = try URL(
        resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil,
        bookmarkDataIsStale: &stale)
      guard url.startAccessingSecurityScopedResource() else {
        return FlutterError(code: "bookmark", message: "폴더 접근이 거부되었다", details: nil)
      }
      opened[url.path] = url
      var reply: [String: Any] = ["path": url.path, "stale": stale]
      if stale, let renewed = try? url.bookmarkData(
        options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
        includingResourceValuesForKeys: nil, relativeTo: nil)
      {
        reply["bookmark"] = FlutterStandardTypedData(bytes: renewed)
      }
      return reply
    } catch {
      return FlutterError(code: "bookmark", message: error.localizedDescription, details: nil)
    }
  }
}
