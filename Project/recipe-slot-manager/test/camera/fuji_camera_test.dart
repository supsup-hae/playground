import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/camera/fuji_camera.dart';
import 'package:recipe_slot_manager/camera/slot_snapshot.dart';
import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/ptp/ptp_string.dart';
import 'package:recipe_slot_manager/ptp/ptp_transport.dart';

import '../support/fake_ptp_transport.dart';

const highlight = 0xD19D;
const shadow = 0xD19E;
const colorTemp = 0xD19C;

Uint8List u16(int value) =>
    (ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List();

/// 슬롯 n의 속성 값은 n*100 + (코드 - D18E), 이름은 'Cn'.
Map<int, Map<int, Uint8List>> sevenSlots() => {
  for (var slot = 1; slot <= FujiProp.slotCount; slot++)
    slot: {
      FujiProp.presetName: encodePtpString('C$slot'),
      for (final code in FujiProp.presetProps)
        code: u16(slot * 100 + code - FujiProp.presetFirst),
    },
};

void main() {
  late FakePtpTransport transport;
  late FujiCamera camera;

  setUp(() {
    transport = FakePtpTransport(slots: sevenSlots(), currentSlot: 3);
    camera = FujiCamera(transport, slotSwitchDelay: Duration.zero);
  });

  group('readAllSlots', () {
    test('C1–C7의 이름과 속성 24개를 읽는다', () async {
      final slots = await camera.readAllSlots();

      expect(slots.map((s) => s.slot), [1, 2, 3, 4, 5, 6, 7]);
      expect(slots[4].name, 'C5');
      expect(slots[4].props.length, 24);
      expect(
        slots[4].props[highlight],
        u16(500 + highlight - FujiProp.presetFirst),
      );
    });

    test('읽은 뒤 원래 선택돼 있던 슬롯으로 되돌린다', () async {
      await camera.readAllSlots();

      expect(transport.currentSlot, 3);
    });

    test('지원하지 않는 속성은 건너뛰고 나머지를 읽는다', () async {
      transport.unsupported.add(0xD191);

      final slots = await camera.readAllSlots();

      expect(slots.first.props.containsKey(0xD191), isFalse);
      expect(slots.first.props.length, 23);
    });

    test('읽지 못한 속성은 슬롯과 코드를 로그에 남긴다', () async {
      transport.unsupported.add(0xD191);

      await camera.readAllSlots();

      final messages = camera.log.entries.map((e) => e.$2);
      expect(messages, contains(contains('C1 D191')));
    });
  });

  group('writeSlot', () {
    late SlotSnapshot current;

    setUp(() async {
      current = (await camera.readAllSlots())[6];
      transport.sent.clear();
    });

    test('현재 값과 다른 속성만 쓴다', () async {
      final target = current.copyWith(
        props: {
          ...current.props,
          highlight: u16(15),
          shadow: u16(-10 & 0xFFFF),
        },
      );

      final result = await camera.writeSlot(target, current: current);

      expect(
        transport.propWrites.map((c) => c.$2.first),
        unorderedEquals([highlight, shadow]),
      );
      expect(result.written, unorderedEquals([highlight, shadow]));
      expect(transport.slots[7]![highlight], u16(15));
    });

    test('이름이 같으면 이름을 쓰지 않고, 다르면 쓴다', () async {
      await camera.writeSlot(current, current: current);
      expect(transport.propWrites, isEmpty);

      await camera.writeSlot(current.copyWith(name: '야간'), current: current);
      expect(transport.propWrites.map((c) => c.$2.first), [
        FujiProp.presetName,
      ]);
      expect(decodePtpString(transport.slots[7]![FujiProp.presetName]!), '야간');
    });

    test('카메라가 거부한 속성은 경고로 남기고 나머지를 계속 쓴다', () async {
      transport.rejectSet[colorTemp] = PtpResponse.invalidParameter;
      final target = current.copyWith(
        props: {...current.props, colorTemp: u16(5500), highlight: u16(15)},
      );

      final result = await camera.writeSlot(target, current: current);

      expect(result.warnings.single, contains('D19C'));
      expect(result.written, [highlight]);
    });

    test('다시 읽은 값이 다르면 불일치로 기록한다', () async {
      transport.readbackOverride[highlight] = u16(99);
      final target = current.copyWith(
        props: {...current.props, highlight: u16(15)},
      );

      final result = await camera.writeSlot(target, current: current);

      expect(result.mismatched, [highlight]);
      expect(result.isClean, isFalse);
    });

    test('슬롯 선택이 거부되면 SlotWriteException 을 던진다', () async {
      transport.rejectSet[FujiProp.presetSlot] = PtpResponse.invalidParameter;
      final target = current.copyWith(
        props: {...current.props, highlight: u16(15)},
      );

      expect(
        () => camera.writeSlot(target, current: current),
        throwsA(isA<SlotWriteException>()),
      );
    });

    test('WB 모드, 색온도, WB 시프트를 카메라가 요구하는 순서로 쓴다', () async {
      final target = current.copyWith(
        props: {
          ...current.props,
          0xD19A: u16(3),
          0xD19B: u16(-2 & 0xFFFF),
          colorTemp: u16(5500),
          0xD199: u16(0x8007),
        },
      );

      await camera.writeSlot(target, current: current);

      expect(transport.propWrites.map((c) => c.$2.first), [
        0xD199,
        colorTemp,
        0xD19A,
        0xD19B,
      ]);
    });

    test('바뀐 값이 없으면 슬롯을 선택하지도 않는다', () async {
      await camera.writeSlot(current, current: current);

      final selects = transport.sent.where(
        (c) =>
            c.$1 == PtpOp.setDevicePropValue &&
            c.$2.first == FujiProp.presetSlot,
      );
      expect(selects, isEmpty);
    });

    test('쓴 뒤 원래 선택돼 있던 슬롯으로 되돌린다', () async {
      await camera.writeSlot(current.copyWith(name: '야간'), current: current);

      expect(transport.currentSlot, 3);
    });
  });

  test('restore 는 백업의 모든 슬롯에 모든 속성을 쓴다', () async {
    final backup = await camera.readAllSlots();
    transport
      ..slots.clear()
      ..sent.clear();

    final results = await camera.restore(backup);

    expect(results.length, 7);
    expect(results.every((r) => r.isClean), isTrue);
    expect(transport.propWrites.length, 7 * 25);
    expect(transport.slots[2]![highlight], backup[1].props[highlight]);
  });

  group('writeSlots', () {
    test('바뀐 슬롯만 쓰고 원래 슬롯으로 되돌린다', () async {
      final current = await camera.readAllSlots();
      transport.sent.clear();
      final targets = [
        for (final slot in current)
          slot.slot == 2 || slot.slot == 5
              ? slot.copyWith(props: {...slot.props, highlight: u16(15)})
              : slot,
      ];

      final results = await camera.writeSlots(targets, current: current);

      expect(results.map((r) => r.slot), [1, 2, 3, 4, 5, 6, 7]);
      expect(results.map((r) => r.written.length), [0, 1, 0, 0, 1, 0, 0]);
      expect(transport.slots[2]![highlight], u16(15));
      expect(transport.slots[5]![highlight], u16(15));
      final selected = transport.sent
          .where(
            (c) =>
                c.$1 == PtpOp.setDevicePropValue &&
                c.$2.first == FujiProp.presetSlot,
          )
          .length;
      expect(selected, 3, reason: 'C2, C5 선택 + 원래 슬롯 복귀');
      expect(transport.currentSlot, 3);
    });

    test('전체 시간을 로그에 남긴다', () async {
      final current = await camera.readAllSlots();

      await camera.writeSlots(current, current: current);

      final messages = camera.log.entries.map((e) => e.$2);
      expect(messages, contains(startsWith('7슬롯 쓰기')));
    });
  });

  test('restore 는 이름이 빈 슬롯의 이름을 덮어쓰지 않는다', () async {
    final backup = await camera.readAllSlots();
    transport.sent.clear();

    await camera.restore([backup.first.copyWith(name: '')]);

    expect(
      transport.propWrites.map((c) => c.$2.first),
      isNot(contains(FujiProp.presetName)),
    );
    expect(decodePtpString(transport.slots[1]![FujiProp.presetName]!), 'C1');
  });

  test('restore 중 전송이 끊기면 PtpTransportException 을 전달한다', () async {
    final backup = await camera.readAllSlots();
    final flaky = _FlakyTransport(transport, failAfter: 30);
    final failing = FujiCamera(flaky, slotSwitchDelay: Duration.zero);

    expect(
      () => failing.restore(backup),
      throwsA(isA<PtpTransportException>()),
    );
  });

  test('전송 오류는 PtpTransportException 그대로 전달한다', () async {
    final failing = FujiCamera(
      _FailingTransport(),
      slotSwitchDelay: Duration.zero,
    );

    expect(failing.readAllSlots, throwsA(isA<PtpTransportException>()));
  });
}

/// [failAfter] 번 보낸 뒤부터 케이블이 빠진 것처럼 실패한다.
class _FlakyTransport implements PtpTransport {
  _FlakyTransport(this._inner, {required this.failAfter});

  final PtpTransport _inner;
  final int failAfter;
  var _count = 0;

  @override
  Future<String> connect() => _inner.connect();

  @override
  Future<void> disconnect() => _inner.disconnect();

  @override
  Future<PtpReply> send(Uint8List command, {Uint8List? data}) {
    if (++_count > failAfter) throw const PtpTransportException('케이블 분리');
    return _inner.send(command, data: data);
  }
}

class _FailingTransport implements PtpTransport {
  @override
  Future<String> connect() async => 'X-T5';

  @override
  Future<void> disconnect() async {}

  @override
  Future<PtpReply> send(Uint8List command, {Uint8List? data}) =>
      throw const PtpTransportException('케이블 분리');
}
