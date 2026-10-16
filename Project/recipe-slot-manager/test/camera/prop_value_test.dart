import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/camera/prop_value.dart';

void main() {
  test('2바이트는 int16, 4바이트는 int32 로 읽는다', () {
    expect(decodePropValue(Uint8List.fromList([0xF6, 0xFF])), -10);
    expect(decodePropValue(Uint8List.fromList([0x7C, 0x15, 0, 0])), 5500);
  });

  test('2·4바이트가 아니면 읽을 수 없다', () {
    expect(decodePropValue(Uint8List.fromList([1, 2, 3])), isNull);
  });

  group('encodePropValue', () {
    test('범위 안의 값은 리틀 엔디언으로 바꾼다', () {
      expect(encodePropValue(-10, 2), [0xF6, 0xFF]);
      expect(encodePropValue(65535, 2), [0xFF, 0xFF]);
      expect(encodePropValue(5500, 4), [0x7C, 0x15, 0, 0]);
    });

    test('바이트 수에 들어가지 않는 값은 null', () {
      expect(encodePropValue(65536, 2), isNull);
      expect(encodePropValue(-32769, 2), isNull);
      expect(encodePropValue(0x100000000, 4), isNull);
      expect(encodePropValue(-0x80000001, 4), isNull);
    });

    test('2·4바이트가 아닌 길이는 null', () {
      expect(encodePropValue(1, 3), isNull);
    });
  });

  test('표시는 16진수와 정수를 함께 보여 준다', () {
    expect(displayPropValue(Uint8List.fromList([0xF6, 0xFF])), 'f6ff (-10)');
    expect(displayPropValue(Uint8List.fromList([1, 2, 3])), '010203');
    expect(displayPropValue(null), '-');
  });
}
