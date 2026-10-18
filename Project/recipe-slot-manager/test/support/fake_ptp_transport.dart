import 'dart:typed_data';

import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/ptp/ptp_transport.dart';

/// 슬롯별 속성 값을 들고 있는 가짜 카메라.
class FakePtpTransport implements PtpTransport {
  FakePtpTransport({required this.slots, this.currentSlot = 1});

  /// 슬롯 번호 → (속성 코드 → 값). 이름은 [FujiProp.presetName] 에 PTP 문자열로 둔다.
  final Map<int, Map<int, Uint8List>> slots;
  int currentSlot;

  /// 읽기에 DevicePropNotSupported 를 돌려줄 속성.
  final unsupported = <int>{};

  /// 쓰기에 돌려줄 응답 코드 (속성 → 코드).
  final rejectSet = <int, int>{};

  /// 쓰기는 받아들이지만 다시 읽으면 이 값을 돌려줄 속성.
  final readbackOverride = <int, Uint8List>{};

  /// 보낸 명령 기록: (명령 코드, 매개변수).
  final sent = <(int, List<int>)>[];

  /// 보낸 명령의 transaction ID, 보낸 순서대로.
  final transactionIds = <int>[];

  /// 있으면 명령을 보낼 때 이 예외를 던진다 (카메라에 닿지 못한 경우).
  PtpTransportException? failure;

  // ---------- RAW 현상 ----------

  /// RAF 를 받은 뒤 0xD185 로 돌려줄 기준 프로필.
  Uint8List rawBaseProfile = Uint8List(0);

  /// 받은 ObjectInfo 와 RAF.
  Uint8List? rafObjectInfo;
  Uint8List? raf;

  /// 0xD185 로 쓴 프로필, 쓴 순서대로.
  final writtenProfiles = <Uint8List>[];

  /// 현상을 시작한 뒤 결과 핸들이 보이기까지 더 불러야 하는 GetObjectHandles 횟수.
  int conversionPolls = 0;

  /// 쓴 프로필로 현상 결과(JPEG 바이트)를 만든다.
  Uint8List Function(Uint8List profile) developResult = (profile) =>
      Uint8List.fromList([0xFF, 0xD8, profile.length & 0xFF, 0xFF, 0xD9]);

  /// 명령 코드별로 돌려줄 실패 응답.
  final rejectOps = <int, int>{};

  /// 첫 현상 결과의 핸들. 현상할 때마다 1씩 늘어난다.
  static const resultHandle = 0x55;

  /// 현상과 상관없이 카메라에 이미 있는 객체(메모리 카드 사진). 받거나 지우면 안 된다.
  final existingHandles = <int>[];

  /// 받은 객체 핸들, 받은 순서대로.
  final fetchedHandles = <int>[];
  final deletedHandles = <int>[];
  Uint8List? _result;
  var _resultHandle = resultHandle - 1;
  var _pollsLeft = 0;

  Iterable<(int, List<int>)> get propWrites => sent.where(
    (c) =>
        c.$1 == PtpOp.setDevicePropValue && c.$2.first != FujiProp.presetSlot,
  );

  @override
  Future<String> connect() async => 'X-T5';

  @override
  Future<void> disconnect() async {}

  @override
  Future<PtpReply> send(
    Uint8List command, {
    Uint8List? data,
    Duration? timeout,
  }) async {
    if (failure case final error?) throw error;
    final view = ByteData.sublistView(command);
    final op = view.getUint16(6, Endian.little);
    final params = [
      for (var offset = 12; offset < command.length; offset += 4)
        view.getUint32(offset, Endian.little),
    ];
    sent.add((op, params));
    transactionIds.add(view.getUint32(8, Endian.little));
    if (rejectOps[op] case final code?) return _reply(code);
    if (_raw(op, params, data) case final reply?) return reply;
    final prop = params.first;

    if (op == PtpOp.getDevicePropValue) {
      if (unsupported.contains(prop)) {
        return _reply(PtpResponse.devicePropNotSupported);
      }
      if (prop == FujiProp.presetSlot) {
        return _reply(PtpResponse.ok, _u16(currentSlot));
      }
      final value = readbackOverride[prop] ?? slots[currentSlot]?[prop];
      return value == null
          ? _reply(PtpResponse.devicePropNotSupported)
          : _reply(PtpResponse.ok, value);
    }

    if (op == PtpOp.setDevicePropValue) {
      final rejected = rejectSet[prop];
      if (rejected != null) return _reply(rejected);
      if (data == null || data.isEmpty) {
        return _reply(PtpResponse.invalidParameter);
      }
      final value = data;
      if (prop == FujiProp.presetSlot) {
        currentSlot = ByteData.sublistView(value).getUint16(0, Endian.little);
      } else {
        slots.putIfAbsent(currentSlot, () => {})[prop] = value;
      }
      return _reply(PtpResponse.ok);
    }

    return _reply(PtpResponse.invalidParameter);
  }

  /// RAW 현상 명령이면 응답, 아니면 null.
  PtpReply? _raw(int op, List<int> params, Uint8List? data) {
    final prop = params.firstOrNull;
    if (op == PtpOp.setDevicePropValue && rejectSet[prop] != null) return null;
    switch (op) {
      case FujiOp.sendObjectInfo:
        rafObjectInfo = data;
        return _reply(PtpResponse.ok);
      case FujiOp.sendObject2:
        raf = data;
        return _reply(PtpResponse.ok);
      case PtpOp.getObjectHandles:
        final ready = _result != null && _pollsLeft-- <= 0;
        final handles = [...existingHandles, if (ready) _resultHandle];
        return _reply(PtpResponse.ok, _u32s([handles.length, ...handles]));
      case PtpOp.getObject:
        fetchedHandles.add(prop!);
        if (existingHandles.contains(prop)) {
          return _reply(PtpResponse.ok, Uint8List.fromList([0xFF, 0xD8, 0x01]));
        }
        final result = _result;
        return result != null && prop == _resultHandle
            ? _reply(PtpResponse.ok, result)
            : _reply(PtpResponse.invalidParameter);
      case PtpOp.deleteObject:
        deletedHandles.add(prop!);
        if (prop == _resultHandle) _result = null;
        return _reply(PtpResponse.ok);
      case PtpOp.getDevicePropValue when prop == FujiProp.rawProfile:
        return _reply(PtpResponse.ok, raf == null ? null : rawBaseProfile);
      case PtpOp.setDevicePropValue when prop == FujiProp.rawProfile:
        writtenProfiles.add(data!);
        return _reply(PtpResponse.ok);
      case PtpOp.setDevicePropValue when prop == FujiProp.startRawConversion:
        _result = developResult(writtenProfiles.last);
        _resultHandle++;
        _pollsLeft = conversionPolls;
        return _reply(PtpResponse.ok);
    }
    return null;
  }

  Uint8List _u32s(List<int> values) {
    final bytes = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      bytes.setUint32(i * 4, values[i], Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  PtpReply _reply(int code, [Uint8List? data]) =>
      PtpReply(code, data ?? Uint8List(0));

  Uint8List _u16(int value) =>
      (ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List();
}
