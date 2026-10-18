import 'dart:typed_data';

import 'package:recipe_slot_manager/camera/d185_profile.dart';
import 'package:recipe_slot_manager/camera/fuji_camera.dart';
import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/ptp/ptp_string.dart';
import 'package:recipe_slot_manager/ptp/ptp_transport.dart';

/// RAW 현상이 카메라에서 실패한 경우. 화면은 [message] 를 그대로 보인다.
final class RawDevelopException implements Exception {
  const RawDevelopException(this.message);

  final String message;

  @override
  String toString() => 'RawDevelopException: $message';
}

/// RAF 를 카메라로 보내고, 레시피를 적용해 카메라 프로세서로 현상한 JPEG 를 받는다.
///
/// 흐름은 FilmKit(MIT) `src/ptp/session.ts` 를 따른다. X100VI 에서 확인되었고 X-T5 에서는
/// 확인되지 않았다.
class RawDeveloper {
  RawDeveloper(
    this.camera, {
    this.pollInterval = const Duration(seconds: 1),
    this.pollTimeout = const Duration(seconds: 30),
    this.transferTimeout = const Duration(seconds: 60),
  });

  final FujiCamera camera;

  /// 현상 결과가 생겼는지 다시 볼 간격과 기다릴 최대 시간.
  final Duration pollInterval;
  final Duration pollTimeout;

  /// RAF 보내기·결과 받기처럼 큰 데이터를 주고받는 명령의 시간 제한.
  final Duration transferTimeout;

  /// RAF 를 보낸 뒤 카메라에서 읽은 기준 프로필. 레시피마다 이것을 복사해 고친다.
  Uint8List? _baseProfile;

  /// RAF 를 보낸 연결. 다시 연결하면 카메라가 RAF 를 잊으므로 다시 보내야 한다.
  int? _rafSession;

  bool get rafLoaded =>
      _baseProfile != null && _rafSession == camera.sessionNumber;

  /// 지금 카메라에 보낸 RAF 의 이름. 보내지 않았으면 null.
  String? get rafName => rafLoaded ? _rafName : null;
  String? _rafName;

  Future<void> loadRaf(Uint8List raf, {String name = 'RAF'}) async {
    _baseProfile = null;
    _rafName = name;
    final watch = Stopwatch()..start();
    await _expectOk(
      'RAF 정보 보내기',
      camera.command(
        FujiOp.sendObjectInfo,
        params: const [0, 0, 0],
        data: rafObjectInfo(raf.length),
      ),
    );
    await _expectOk(
      'RAF 보내기',
      camera.command(FujiOp.sendObject2, data: raf, timeout: transferTimeout),
    );
    final profile = await _expectOk(
      '현상 설정 읽기',
      camera.command(
        PtpOp.getDevicePropValue,
        params: const [FujiProp.rawProfile],
      ),
    );
    if (profile.data.isEmpty) {
      throw const RawDevelopException('카메라가 RAF 를 받지 않았다 (현상 설정이 비어 있다)');
    }
    _baseProfile = profile.data;
    _rafSession = camera.sessionNumber;
    camera.log.add(
      'RAF 보내기: ${(raf.length / (1024 * 1024)).toStringAsFixed(1)} MB, '
      '${watch.elapsedMilliseconds}ms',
    );
  }

  /// [values] 를 적용해 현상한 JPEG 바이트.
  Future<Uint8List> develop(Map<String, double> values) async {
    final base = _baseProfile;
    if (base == null || !rafLoaded) {
      throw const RawDevelopException('RAF 를 먼저 보낼 것');
    }
    final watch = Stopwatch()..start();
    await _expectOk(
      '현상 설정 쓰기',
      camera.command(
        PtpOp.setDevicePropValue,
        params: const [FujiProp.rawProfile],
        data: patchD185(base, values),
      ),
    );
    // 시작 전에 있던 객체(메모리 카드 사진, 앞 현상이 남긴 결과)는 결과로 보지 않는다.
    final before = (await _handlesNow()).toSet();
    await _expectOk(
      '현상 시작',
      camera.command(
        PtpOp.setDevicePropValue,
        params: const [FujiProp.startRawConversion],
        data: Uint8List(2),
      ),
    );
    final handle = await _waitForResult(before);
    final result = await _expectOk(
      '현상 결과 받기',
      camera.command(
        PtpOp.getObject,
        params: [handle],
        timeout: transferTimeout,
      ),
    );
    // 카메라에 남은 임시 결과를 지운다. 실패해도 결과는 이미 받았으므로 로그만 남긴다.
    try {
      await camera.command(PtpOp.deleteObject, params: [handle]);
    } on PtpTransportException catch (e) {
      camera.log.add('현상 결과를 카메라에서 지우지 못했다: ${e.message}');
    }
    final jpeg = result.data;
    if (jpeg.length < 2 || jpeg[0] != 0xFF || jpeg[1] != 0xD8) {
      throw const RawDevelopException('현상 결과가 JPEG 이 아니다');
    }
    camera.log.add('현상: ${watch.elapsedMilliseconds}ms');
    return jpeg;
  }

  /// [before] 에 없던 JPEG 객체가 생길 때까지 [pollInterval] 마다 객체 목록을 본다.
  /// 새로 생겼어도 JPEG 이 아닌 객체는 결과로 보지 않는다.
  Future<int> _waitForResult(Set<int> before) async {
    final seen = {...before};
    final watch = Stopwatch()..start();
    while (true) {
      for (final handle in await _handlesNow()) {
        if (seen.add(handle) && await _isJpeg(handle)) return handle;
      }
      if (watch.elapsed >= pollTimeout) {
        throw RawDevelopException(
          '현상 결과가 ${pollTimeout.inSeconds}초 안에 나오지 않았다',
        );
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<bool> _isJpeg(int handle) async {
    final info = await camera.command(PtpOp.getObjectInfo, params: [handle]);
    return info.isOk &&
        info.data.length >= 6 &&
        ByteData.sublistView(info.data).getUint16(4, Endian.little) ==
            PtpObjectFormat.jpeg;
  }

  Future<List<int>> _handlesNow() async {
    final reply = await _expectOk(
      '현상 결과 찾기',
      camera.command(PtpOp.getObjectHandles, params: const [0xFFFFFFFF, 0, 0]),
    );
    return _handles(reply.data);
  }

  Future<PtpReply> _expectOk(String step, Future<PtpReply> reply) async {
    final value = await reply;
    if (!value.isOk) {
      throw RawDevelopException(
        '$step 실패 (응답 0x${value.code.toRadixString(16)})',
      );
    }
    return value;
  }
}

/// 객체 핸들 배열: u32 개수 + u32 × 개수.
List<int> _handles(Uint8List data) {
  if (data.length < 4) return const [];
  final view = ByteData.sublistView(data);
  final count = view.getUint32(0, Endian.little);
  return [
    for (var i = 0; i < count && 4 + i * 4 + 4 <= data.length; i++)
      view.getUint32(4 + i * 4, Endian.little),
  ];
}

/// RAF 를 보내기 전에 알리는 PTP ObjectInfo. 형식은 [FujiOp.rafFormat], 이름은 `FUP_FILE.dat`,
/// 날짜·키워드는 빈 문자열, 나머지는 0 이다.
Uint8List rafObjectInfo(int size) {
  final head = ByteData(52)
    ..setUint16(4, FujiOp.rafFormat, Endian.little)
    ..setUint32(8, size, Endian.little);
  return Uint8List.fromList([
    ...head.buffer.asUint8List(),
    ...encodePtpString('FUP_FILE.dat'),
    0, 0, 0, // 촬영 날짜, 수정 날짜, 키워드
  ]);
}
