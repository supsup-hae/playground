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

  Iterable<(int, List<int>)> get propWrites => sent.where(
    (c) =>
        c.$1 == PtpOp.setDevicePropValue && c.$2.first != FujiProp.presetSlot,
  );

  @override
  Future<String> connect() async => 'X-T5';

  @override
  Future<void> disconnect() async {}

  @override
  Future<PtpReply> send(Uint8List command, {Uint8List? data}) async {
    if (failure case final error?) throw error;
    final view = ByteData.sublistView(command);
    final op = view.getUint16(6, Endian.little);
    final params = [
      for (var offset = 12; offset < command.length; offset += 4)
        view.getUint32(offset, Endian.little),
    ];
    sent.add((op, params));
    transactionIds.add(view.getUint32(8, Endian.little));
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

  PtpReply _reply(int code, [Uint8List? data]) =>
      PtpReply(code, data ?? Uint8List(0));

  Uint8List _u16(int value) =>
      (ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List();
}
