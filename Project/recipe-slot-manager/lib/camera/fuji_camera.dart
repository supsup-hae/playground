import 'package:flutter/foundation.dart';
import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/camera/slot_snapshot.dart';
import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/ptp/ptp_container.dart';
import 'package:recipe_slot_manager/ptp/ptp_string.dart';
import 'package:recipe_slot_manager/ptp/ptp_transport.dart';

/// 후지필름 카메라의 커스텀 슬롯 C1–C7을 읽고 쓴다.
///
/// 모든 작업은 끝난 뒤 카메라에서 원래 선택돼 있던 슬롯으로 되돌린다.
class FujiCamera {
  FujiCamera(
    this._transport, {
    this.slotSwitchDelay = const Duration(milliseconds: 100),
    CameraLog? log,
  }) : log = log ?? CameraLog();

  final PtpTransport _transport;

  /// 슬롯을 선택한 뒤 값을 읽거나 쓰기 전까지 기다리는 시간.
  final Duration slotSwitchDelay;
  final CameraLog log;

  var _transactionId = 0;
  var _roundTrips = 0;

  /// 지금 작업에서 슬롯을 선택했는지. 끝날 때 원래 슬롯으로 되돌릴지 정한다.
  var _slotChanged = false;

  /// 연결할 때마다 1씩 는다. 카메라 쪽 상태(보낸 RAF 등)가 이 세션에 속하는지 가린다.
  int get sessionNumber => _sessionNumber;
  var _sessionNumber = 0;

  /// 새 세션을 연다. PTP 규칙대로 세션마다 transaction ID 를 1 부터 다시 센다.
  Future<String> connect() async {
    final model = await _transport.connect();
    _transactionId = 0;
    _sessionNumber++;
    log.add('$model 연결');
    return model;
  }

  Future<void> disconnect() => _transport.disconnect();

  Future<List<SlotSnapshot>> readAllSlots() => _keepingSelectedSlot(() async {
    final timing = _startTiming();
    final slots = [
      for (var slot = 1; slot <= FujiProp.slotCount; slot++)
        await _readSlot(slot),
    ];
    _logTiming('C1–C7 불러오기', timing);
    return slots;
  });

  /// [target] 슬롯에 이름과 속성을 쓰고 다시 읽어 검증한다.
  /// [current] 가 있으면 그와 바이트가 다른 값만 쓴다.
  Future<SlotWriteResult> writeSlot(
    SlotSnapshot target, {
    SlotSnapshot? current,
  }) => _keepingSelectedSlot(() => _writeSlot(target, current));

  /// 여러 슬롯을 한 번에 쓴다. 슬롯마다 [current] 에서 같은 번호의 스냅숏과 비교해
  /// 바뀐 값만 쓰고, 바뀐 값이 없는 슬롯은 선택하지 않는다. 중간에 실패하면 그대로 던진다.
  Future<List<SlotWriteResult>> writeSlots(
    List<SlotSnapshot> targets, {
    required List<SlotSnapshot> current,
  }) => _keepingSelectedSlot(() async {
    final timing = _startTiming();
    final bySlot = {for (final slot in current) slot.slot: slot};
    final results = [
      for (final target in targets)
        await _writeSlot(target, bySlot[target.slot]),
    ];
    _logTiming('C1–C7 저장', timing);
    return results;
  });

  /// 백업의 모든 슬롯에 모든 값을 쓴다.
  Future<List<SlotWriteResult>> restore(List<SlotSnapshot> backup) =>
      _keepingSelectedSlot(
        () async => [for (final slot in backup) await _writeSlot(slot, null)],
      );

  Future<SlotSnapshot> _readSlot(int slot) async {
    await _selectSlot(slot);
    final name = await _readSlotProp(slot, FujiProp.presetName);
    final props = <int, Uint8List>{};
    for (final code in FujiProp.presetProps) {
      final value = await _readSlotProp(slot, code);
      if (value != null) props[code] = value;
    }
    return SlotSnapshot(
      slot: slot,
      name: name == null ? '' : decodePtpString(name),
      props: props,
    );
  }

  /// 읽지 못했거나 값이 비어 있으면 로그에 남기고 null.
  Future<Uint8List?> _readSlotProp(int slot, int code) async {
    final reply = await _send(PtpOp.getDevicePropValue, code);
    if (reply.isOk && reply.data.isNotEmpty) return reply.data;
    log.add(
      'C$slot ${propLabel(code)} 불러오기 실패 (0x${reply.code.toRadixString(16)})',
    );
    return null;
  }

  Future<SlotWriteResult> _writeSlot(
    SlotSnapshot target,
    SlotSnapshot? current,
  ) async {
    final timing = _startTiming();
    final values = <int, Uint8List>{
      // 이름을 읽지 못한 슬롯은 빈 이름이 되므로, 빈 이름으로 덮어쓰지 않는다.
      if (target.name.isNotEmpty && target.name != current?.name)
        FujiProp.presetName: encodePtpString(target.name),
      for (final code in FujiProp.writeOrder)
        if (target.props[code] case final value?
            when !listEquals(current?.props[code], value))
          code: value,
    };
    if (values.isEmpty) {
      return SlotWriteResult(
        slot: target.slot,
        written: const [],
        warnings: const [],
        mismatched: const [],
        elapsed: Duration.zero,
      );
    }
    await _selectSlot(target.slot);

    final written = <int>[];
    final warnings = <String>[];
    for (final MapEntry(:key, :value) in values.entries) {
      final code = await _setProp(key, value);
      if (code == PtpResponse.ok) {
        written.add(key);
      } else {
        warnings.add('${propLabel(key)}: 거부 (0x${code.toRadixString(16)})');
      }
    }

    final mismatched = <int>[
      for (final key in written)
        if (!listEquals(await _getProp(key), values[key])) key,
    ];

    final elapsed = _logTiming('C${target.slot} 저장 ${written.length}개', timing);
    return SlotWriteResult(
      slot: target.slot,
      written: written,
      warnings: warnings,
      mismatched: mismatched,
      elapsed: elapsed,
    );
  }

  Future<T> _keepingSelectedSlot<T>(Future<T> Function() action) async {
    final original = await _getProp(FujiProp.presetSlot);
    _slotChanged = false;
    try {
      return await action();
    } finally {
      // 슬롯을 한 번도 바꾸지 않았으면 되돌릴 필요가 없다.
      if (original != null && _slotChanged) {
        final code = await _setProp(FujiProp.presetSlot, original);
        if (code != PtpResponse.ok) {
          log.add('원래 C 번호 복귀 실패 (0x${code.toRadixString(16)})');
        }
      }
    }
  }

  Future<void> _selectSlot(int slot) async {
    final value = (ByteData(
      2,
    )..setUint16(0, slot, Endian.little)).buffer.asUint8List();
    _slotChanged = true;
    final code = await _setProp(FujiProp.presetSlot, value);
    if (code != PtpResponse.ok) {
      throw SlotWriteException('C$slot 선택 거부 (0x${code.toRadixString(16)})');
    }
    await Future<void>.delayed(slotSwitchDelay);
  }

  /// 카메라가 OK가 아닌 응답을 주면 null.
  Future<Uint8List?> _getProp(int prop) async {
    final reply = await _send(PtpOp.getDevicePropValue, prop);
    return reply.isOk ? reply.data : null;
  }

  Future<int> _setProp(int prop, Uint8List value) async =>
      (await _send(PtpOp.setDevicePropValue, prop, data: value)).code;

  Future<PtpReply> _send(int op, int prop, {Uint8List? data}) =>
      command(op, params: [prop], data: data);

  /// 명령 하나를 보낸다. 슬롯 작업과 RAW 현상이 이 세션의 transaction ID 를 함께 쓴다.
  Future<PtpReply> command(
    int op, {
    List<int> params = const [],
    Uint8List? data,
    Duration? timeout,
  }) {
    _roundTrips++;
    final command = ptpCommand(
      op,
      transactionId: ++_transactionId,
      params: params,
    );
    return _transport.send(command, data: data, timeout: timeout);
  }

  (Stopwatch, int) _startTiming() => (Stopwatch()..start(), _roundTrips);

  Duration _logTiming(String label, (Stopwatch, int) timing) {
    final (watch, startCount) = timing;
    final count = _roundTrips - startCount;
    final ms = watch.elapsedMilliseconds;
    final average = count == 0 ? '0' : (ms / count).toStringAsFixed(1);
    log.add('$label: ${ms}ms, 왕복 $count회 (평균 ${average}ms)');
    return watch.elapsed;
  }
}

final class SlotWriteResult {
  const SlotWriteResult({
    required this.slot,
    required this.written,
    required this.warnings,
    required this.mismatched,
    required this.elapsed,
  });

  final int slot;

  /// 카메라가 받아들인 속성 코드. 이름은 [FujiProp.presetName].
  final List<int> written;

  /// 카메라가 거부한 속성 설명.
  final List<String> warnings;

  /// 받아들였지만 다시 읽은 값이 다른 속성 코드.
  final List<int> mismatched;
  final Duration elapsed;

  bool get isClean => warnings.isEmpty && mismatched.isEmpty;
}

/// 슬롯을 선택하지 못해 쓰기를 시작할 수 없는 경우.
final class SlotWriteException implements Exception {
  const SlotWriteException(this.message);

  final String message;

  @override
  String toString() => 'SlotWriteException: $message';
}
