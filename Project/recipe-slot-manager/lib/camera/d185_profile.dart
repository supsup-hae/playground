import 'dart:typed_data';

import 'package:recipe_slot_manager/recipe/recipe_fields.dart';

/// RAW 현상 프로필(속성 0xD185)의 매개변수 칸 → 레시피 필드.
///
/// 출처: FilmKit(MIT) `src/profile/d185.ts`. X100VI 에서 확인되었고 X-T5 에서는 확인되지 않았다.
/// 값 인코딩은 슬롯 속성과 같다. 모노 WC·MG 와 노출 보정은 칸이 확인되지 않아 다루지 않는다.
const d185Slots = {
  'dynamicRange': 6,
  'filmSimulation': 8,
  'grain': 9,
  'colorChrome': 10,
  'smoothSkin': 11,
  'whiteBalance': 12,
  'wbShiftRed': 13,
  'wbShiftBlue': 14,
  'colorTemperature': 15,
  'highlight': 16,
  'shadow': 17,
  'color': 18,
  'sharpness': 19,
  'noiseReduction': 20,
  'colorChromeFxBlue': 25,
  'clarity': 27,
};

/// [base] 프로필을 복사해 [values] 중 칸이 있고 범위 안이며 지금 필름 시뮬레이션에서 의미
/// 있는 필드만 고친다. 고치지 않은 칸은 RAF 의 EXIF 값으로 현상된다.
///
/// 형식: 첫 u16 이 매개변수 개수 n, 마지막 n × 4 바이트가 int32(리틀 엔디언) 배열.
Uint8List patchD185(Uint8List base, Map<String, double> values) {
  if (base.length < 2) {
    throw FormatException('D185 프로필 ${base.length}바이트: 너무 짧음');
  }
  final patched = Uint8List.fromList(base);
  final view = ByteData.sublistView(patched);
  final count = view.getUint16(0, Endian.little);
  final start = patched.length - count * 4;
  if (start < 2) {
    throw FormatException('D185 프로필 길이 ${base.length}: 매개변수 $count개보다 짧음');
  }
  for (final MapEntry(:key, :value) in values.entries) {
    final slot = d185Slots[key];
    final field = fieldById[key];
    if (slot == null || field == null || slot >= count) continue;
    if (!field.accepts(value) || !isApplicable(field, values)) continue;
    view.setInt32(start + slot * 4, _native(field, value), Endian.little);
  }
  return patched;
}

/// 눈금 필드는 부호 있는 정수(×배율), 나머지는 슬롯 속성 값 그대로.
int _native(RecipeField field, double value) => switch (field) {
  ScaleField(:final multiplier) => (value * multiplier).round(),
  _ => field.encode(value),
};
