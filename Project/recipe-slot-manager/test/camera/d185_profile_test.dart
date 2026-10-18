import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/camera/d185_profile.dart';

const paramCount = 30;

/// 앞쪽 바이트 + 매개변수 30개(칸 n 의 값은 1000 + n). 카메라 기본 프로필처럼 625바이트.
Uint8List baseProfile() {
  final bytes = Uint8List(625);
  final view = ByteData.sublistView(bytes)
    ..setUint16(0, paramCount, Endian.little);
  final start = bytes.length - paramCount * 4;
  for (var n = 0; n < paramCount; n++) {
    view.setInt32(start + n * 4, 1000 + n, Endian.little);
  }
  return bytes;
}

int slot(Uint8List profile, int n) =>
    ByteData.sublistView(profile)
        .getInt32(profile.length - paramCount * 4 + n * 4, Endian.little);

void main() {
  test('레시피 값을 칸에 슬롯과 같은 인코딩으로 쓰고, 눈금은 부호 있는 ×10 이다', () {
    final patched = patchD185(baseProfile(), {
      'filmSimulation': 0x11,
      'grain': 4,
      'colorChrome': 3,
      'colorChromeFxBlue': 2,
      'dynamicRange': 400,
      'whiteBalance': 0x8007,
      'colorTemperature': 5600,
      'wbShiftRed': 2,
      'wbShiftBlue': -4,
      'highlight': -1.5,
      'shadow': 0.5,
      'color': 3,
      'sharpness': -2,
      'noiseReduction': -4,
      'clarity': -3,
    });

    expect(slot(patched, 8), 0x11);
    expect(slot(patched, 9), 4);
    expect(slot(patched, 10), 3);
    expect(slot(patched, 25), 2);
    expect(slot(patched, 6), 400);
    expect(slot(patched, 12), 0x8007);
    expect(slot(patched, 15), 5600);
    expect(slot(patched, 13), 2);
    expect(slot(patched, 14), -4);
    expect(slot(patched, 16), -15);
    expect(slot(patched, 17), 5);
    expect(slot(patched, 18), 30);
    expect(slot(patched, 19), -20);
    expect(slot(patched, 20), 0x8000);
    expect(slot(patched, 27), -30);
  });

  test('레시피에 없는 칸과 앞쪽 바이트는 그대로 둔다', () {
    final base = baseProfile()..[100] = 0xAB;

    final patched = patchD185(base, {'highlight': 1});

    expect(slot(patched, 16), 10);
    expect(slot(patched, 17), 1017);
    expect(slot(patched, 4), 1004);
    expect(patched[100], 0xAB);
    expect(base[100], 0xAB, reason: '기준 프로필은 바꾸지 않는다');
    expect(slot(base, 16), 1016);
  });

  test('흑백이면 컬러 칸을 고치지 않고, 범위 밖 값과 칸이 없는 필드는 무시한다', () {
    final patched = patchD185(baseProfile(), {
      'filmSimulation': 0x0C,
      'color': 2,
      'monoWarmCool': 3,
      'shadow': 9,
    });

    expect(slot(patched, 8), 0x0C);
    expect(slot(patched, 18), 1018);
    expect(slot(patched, 17), 1017);
  });

  test('매개변수 개수가 프로필 길이보다 크면 FormatException', () {
    final broken = Uint8List(40)..[0] = 30;

    expect(() => patchD185(broken, {'highlight': 1}), throwsFormatException);
  });
}
