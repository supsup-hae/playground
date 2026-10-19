import 'package:flutter/services.dart';
import 'package:recipe_slot_manager/ptp/ptp_transport.dart';

/// 플랫폼 쪽 카메라 연결 코드와 이야기하는 채널. macOS 는 Swift, Android 는 Kotlin 이 받는다.
const ptpChannel = MethodChannel('recipe_slot_manager/ptp');

/// 채널 호출의 플랫폼 오류와 형식 오류를 [PtpTransportException] 으로 바꾼다.
Future<T> guardPtpChannel<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on PlatformException catch (e) {
    throw PtpTransportException(e.message ?? e.code);
  } on MissingPluginException {
    throw const PtpTransportException('이 기기에서는 카메라 연결을 지원하지 않음');
  } on FormatException catch (e) {
    throw PtpTransportException(e.message);
  }
}
