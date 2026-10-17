import 'dart:typed_data';

import 'package:recipe_slot_manager/ptp/ptp_codes.dart';

/// 카메라와 PTP 명령을 주고받는 통로. 플랫폼마다 구현이 하나씩 있다.
abstract interface class PtpTransport {
  /// 카메라를 찾아 PTP 세션을 열고 모델 이름을 돌려준다.
  Future<String> connect();

  /// 명령 컨테이너를 보내고 응답을 받는다. [data] 는 카메라로 보내는 값 바이트다.
  Future<PtpReply> send(Uint8List command, {Uint8List? data});

  Future<void> disconnect();
}

final class PtpReply {
  const PtpReply(this.code, this.data);

  /// PTP 응답 코드.
  final int code;

  /// 카메라가 돌려준 값 바이트. 없으면 비어 있다.
  final Uint8List data;

  bool get isOk => code == PtpResponse.ok;
}

/// 카메라에 닿지 못한 경우(장치 없음, 시간 초과, 연결 끊김).
final class PtpTransportException implements Exception {
  const PtpTransportException(this.message);

  final String message;

  @override
  String toString() => 'PtpTransportException: $message';
}
