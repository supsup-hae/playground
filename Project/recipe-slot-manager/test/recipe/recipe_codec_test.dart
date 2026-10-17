import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/camera/slot_snapshot.dart';
import 'package:recipe_slot_manager/recipe/recipe_codec.dart';
import 'package:recipe_slot_manager/recipe/recipe_fields.dart';

Uint8List u16(int value) => (ByteData(
  2,
)..setUint16(0, value & 0xFFFF, Endian.little)).buffer.asUint8List();

/// Classic Neg. 컬러 레시피가 들어 있는 슬롯. 레시피가 다루지 않는 D18E 는 0x0B.
SlotSnapshot classicNegSlot() => SlotSnapshot(
  slot: 2,
  name: 'Classic Neg',
  props: {
    0xD18E: u16(0x0B),
    0xD190: u16(200),
    0xD192: u16(0x11),
    0xD193: u16(0),
    0xD194: u16(0),
    0xD195: u16(2),
    0xD196: u16(3),
    0xD197: u16(1),
    0xD198: u16(1),
    0xD199: u16(0x0002),
    0xD19A: u16(2),
    0xD19B: u16(-4),
    0xD19C: u16(0),
    0xD19D: u16(-10),
    0xD19E: u16(15),
    0xD19F: u16(20),
    0xD1A0: u16(-20),
    0xD1A1: u16(0x4000),
    0xD1A2: u16(-30),
  },
);

void main() {
  group('decodeSlot', () {
    test('슬롯 속성을 사람이 읽는 값으로 바꾼다', () {
      final values = decodeSlot(classicNegSlot());

      expect(values, {
        'filmSimulation': 0x11,
        'dynamicRange': 200,
        'grain': 2,
        'colorChrome': 3,
        'colorChromeFxBlue': 1,
        'smoothSkin': 1,
        'whiteBalance': 0x0002,
        'wbShiftRed': 2,
        'wbShiftBlue': -4,
        'highlight': -1,
        'shadow': 1.5,
        'color': 2,
        'sharpness': -2,
        'noiseReduction': -2,
        'clarity': -3,
      });
    });

    test('표에 없는 값과 0x8000 은 "카메라 값 유지"(빠짐)로 둔다', () {
      final slot = classicNegSlot();
      final values = decodeSlot(
        slot.copyWith(
          props: {...slot.props, 0xD192: u16(0x99), 0xD19D: u16(0x8000)},
        ),
      );

      expect(values.containsKey('filmSimulation'), isFalse);
      expect(values.containsKey('highlight'), isFalse);
    });

    test('흑백 시뮬레이션이면 컬러 대신 모노 WC·MG 를 읽는다', () {
      final slot = classicNegSlot();
      final values = decodeSlot(
        slot.copyWith(
          props: {
            ...slot.props,
            0xD192: u16(0x0C),
            0xD193: u16(30),
            0xD194: u16(-20),
          },
        ),
      );

      expect(values['monoWarmCool'], 3);
      expect(values['monoMagentaGreen'], -2);
      expect(values.containsKey('color'), isFalse);
    });

    test('WB 가 색온도일 때만 색온도를 읽는다', () {
      final slot = classicNegSlot();
      final values = decodeSlot(
        slot.copyWith(
          props: {...slot.props, 0xD199: u16(0x8007), 0xD19C: u16(5500)},
        ),
      );

      expect(values['whiteBalance'], 0x8007);
      expect(values['colorTemperature'], 5500);
    });
  });

  group('encodeValues', () {
    test('decode 한 값을 다시 encode 하면 같은 바이트가 된다', () {
      final slot = classicNegSlot();

      final encoded = encodeValues(slot.name, decodeSlot(slot), base: slot);

      expect(encoded.toJson(), slot.toJson());
    });

    test('바꾼 필드만 덮어쓰고 레시피 밖 속성은 그대로 둔다', () {
      final slot = classicNegSlot();

      final encoded = encodeValues('야간', {
        'highlight': 1.5,
        'noiseReduction': 4,
      }, base: slot);

      expect(encoded.name, '야간');
      expect(encoded.props[0xD19D], u16(15));
      expect(encoded.props[0xD1A1], u16(0x5000));
      expect(encoded.props[0xD18E], u16(0x0B));
      expect(encoded.props[0xD192], u16(0x11));
    });

    test('WB 가 색온도가 아니면 색온도를 쓰지 않는다', () {
      final slot = classicNegSlot();

      final encoded = encodeValues(slot.name, {
        'whiteBalance': 0x0004,
        'colorTemperature': 5500,
      }, base: slot);

      expect(encoded.props[0xD199], u16(0x0004));
      expect(encoded.props[0xD19C], u16(0));
    });

    test('흑백이면 컬러를 쓰지 않고, 모노 WC·MG 는 0 이 아닐 때만 쓴다', () {
      final slot = classicNegSlot();

      final encoded = encodeValues(slot.name, {
        'filmSimulation': 0x0C,
        'color': 4,
        'monoWarmCool': 0,
        'monoMagentaGreen': 2,
      }, base: slot);

      expect(encoded.props[0xD19F], u16(20));
      expect(encoded.props[0xD193], u16(0));
      expect(encoded.props[0xD194], u16(20));
    });

    test('컬러 시뮬레이션이면 모노 WC·MG 를 쓰지 않는다', () {
      final slot = classicNegSlot();

      final encoded = encodeValues(slot.name, {'monoWarmCool': 5}, base: slot);

      expect(encoded.props[0xD193], u16(0));
    });

    test('카메라가 갖고 있지 않은 속성은 만들지 않는다', () {
      final slot = classicNegSlot();
      final base = slot.copyWith(props: Map.of(slot.props)..remove(0xD1A2));

      final encoded = encodeValues(slot.name, {'clarity': 2}, base: base);

      expect(encoded.props.containsKey(0xD1A2), isFalse);
    });
  });

  test('필드 표의 속성 코드는 겹치지 않는다', () {
    final props = recipeFields.map((f) => f.prop).toList();
    expect(props.toSet().length, props.length);
  });
}
