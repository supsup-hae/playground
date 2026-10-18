import 'dart:typed_data';

import 'package:recipe_slot_manager/import/jpeg_exif.dart';
import 'package:recipe_slot_manager/import/recipe_import.dart';

/// 후지 MakerNote 의 태그 → 값 목록. `FUJIFILM` 8바이트 뒤 u32 가 IFD 위치이고,
/// 위치는 모두 MakerNote 시작 기준, 바이트 순서는 늘 리틀 엔디언이다.
Map<int, List<int>> readFujiTags(Uint8List makerNote) {
  if (makerNote.length < 12 ||
      String.fromCharCodes(makerNote.sublist(0, 8)) != 'FUJIFILM') {
    throw const ImportException('후지필름 카메라로 찍은 사진이 아니다');
  }
  final view = ByteData.sublistView(makerNote);
  final entries = readIfd(
    view,
    view.getUint32(8, Endian.little),
    Endian.little,
  );
  return {
    for (final MapEntry(:key, :value) in entries.entries)
      key: ifdValues(view, value, Endian.little),
  };
}

// 아래 표는 ExifTool FujiFilm 태그 표 기준이며 X-T5 표본 JPEG 로 확인하기 전이다.

/// FilmMode(0x1401) → 필름 시뮬레이션 코드 (컬러).
const _filmModes = {
  0x000: 0x01,
  0x200: 0x02,
  0x400: 0x02,
  0x120: 0x03,
  0x500: 0x05,
  0x501: 0x04,
  0x600: 0x0B,
  0x700: 0x10,
  0x800: 0x11,
  0x900: 0x12,
  0xA00: 0x13,
  0xB00: 0x14,
};

/// Saturation(0x1003) 의 흑백 값 → 필름 시뮬레이션 코드.
const _monochromes = {
  0x300: 0x06,
  0x301: 0x08,
  0x302: 0x07,
  0x303: 0x09,
  0x310: 0x0A,
  0x500: 0x0C,
  0x501: 0x0E,
  0x502: 0x0D,
  0x503: 0x0F,
};

/// Saturation(0x1003) 의 컬러 값 → 레시피 컬러.
const _colors = {
  0x000: 0,
  0x080: 1,
  0x100: 2,
  0x0C0: 3,
  0x0E0: 4,
  0x180: -1,
  0x400: -2,
  0x4C0: -3,
  0x4E0: -4,
};

const _sharpness = {
  0x00: -4,
  0x01: -3,
  0x02: -2,
  0x82: -1,
  0x03: 0,
  0x84: 1,
  0x04: 2,
  0x05: 3,
  0x06: 4,
};

const _noiseReduction = {
  0x000: 0,
  0x180: 1,
  0x100: 2,
  0x1C0: 3,
  0x1E0: 4,
  0x280: -1,
  0x200: -2,
  0x2C0: -3,
  0x2E0: -4,
};

/// WhiteBalance(0x1002) → 레시피 WB 코드. 흰색 우선 오토(0x001)는 필드 표에 없다.
const _whiteBalances = {
  0x000: 0x0002,
  0x002: 0x8021,
  0x100: 0x0004,
  0x200: 0x8006,
  0x300: 0x8001,
  0x301: 0x8002,
  0x302: 0x8003,
  0x400: 0x0006,
  0x600: 0x0008,
  0xFF0: 0x8007,
};

/// 효과 세기(0 끔, 32 약, 64 강) → 레시피 선택지 코드.
const _effects = {0: 1, 32: 2, 64: 3};

/// WhiteBalanceFineTune 한 칸의 원시 값. 표본으로 확인할 것.
const _wbShiftUnit = 20;

/// 후지 MakerNote 태그에서 레시피 값을 만든다. 표에 없는 값과 없는 태그는 빠진다.
Map<String, double> decodeFujiRecipe(Map<int, List<int>> tags) {
  int? tag(int code, [int index = 0]) {
    final values = tags[code];
    return values == null || values.length <= index ? null : values[index];
  }

  double? lookup(Map<int, int> table, int? raw) =>
      raw == null ? null : table[raw]?.toDouble();

  final saturation = tag(0x1003);
  final monochrome = lookup(_monochromes, saturation);
  final whiteBalance = lookup(_whiteBalances, tag(0x1002));
  final grain = _grain(tag(0x1047), tag(0x104C));
  return {
    if (monochrome != null) ...{
      'filmSimulation': monochrome,
      'monoWarmCool': ?tag(0x1049)?.toDouble(),
      'monoMagentaGreen': ?tag(0x104B)?.toDouble(),
    } else ...{
      'filmSimulation': ?lookup(_filmModes, tag(0x1401)),
      'color': ?lookup(_colors, saturation),
    },
    'sharpness': ?lookup(_sharpness, tag(0x1001)),
    'highlight': ?_tone(tag(0x1041)),
    'shadow': ?_tone(tag(0x1040)),
    'noiseReduction': ?lookup(_noiseReduction, tag(0x100E)),
    'clarity': ?_divided(tag(0x100F), 1000),
    'grain': ?grain,
    'colorChrome': ?lookup(_effects, tag(0x1048)),
    'colorChromeFxBlue': ?lookup(_effects, tag(0x104E)),
    'whiteBalance': ?whiteBalance,
    if (whiteBalance == 0x8007) 'colorTemperature': ?tag(0x1005)?.toDouble(),
    'wbShiftRed': ?_divided(tag(0x100A, 0), _wbShiftUnit),
    'wbShiftBlue': ?_divided(tag(0x100A, 1), _wbShiftUnit),
    'dynamicRange': ?tag(0x1403)?.toDouble(),
  };
}

/// 하이라이트·섀도 톤: 원시 값은 −16 이 +1 이다.
double? _tone(int? raw) => _divided(raw, -16);

double? _divided(int? raw, int divisor) => raw == null ? null : raw / divisor;

/// 거칠기(0 끔, 32 약, 64 강)와 크기(16 소, 32 대)로 그레인 선택지를 정한다.
double? _grain(int? roughness, int? size) => switch ((roughness, size)) {
  (0, _) => 1,
  (32, 32) => 4,
  (64, 32) => 5,
  (32, _) => 2,
  (64, _) => 3,
  _ => null,
};
