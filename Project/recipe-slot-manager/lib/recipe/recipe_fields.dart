import 'package:recipe_slot_manager/util/step_value.dart';

/// 레시피 필드 하나: 카메라 슬롯 속성 하나와 그 값의 해석.
///
/// 카메라 값은 슬롯 속성의 u16 원시 값이고, 레시피 값은 사람이 다루는 숫자
/// (선택지 코드, 하이라이트 +1.5 같은 눈금 값)다.
sealed class RecipeField {
  const RecipeField({
    required this.id,
    required this.label,
    required this.prop,
  });

  /// JSON·코드에서 쓰는 이름 (`highlight`).
  final String id;

  /// 화면에 보이는 이름 (`하이라이트`).
  final String label;

  /// 슬롯 속성 코드 (0xD19D).
  final int prop;

  /// 카메라 u16 값을 레시피 값으로. 해석할 수 없으면 null.
  double? decode(int raw);

  /// 레시피 값을 카메라 u16 값으로. [accepts] 가 참인 값만 넘긴다.
  int encode(double value);

  bool accepts(double value);

  String display(double value);
}

/// 정해진 선택지 중 하나 (필름 시뮬레이션, 그레인 등). 레시피 값은 카메라 코드 그대로다.
final class ChoiceField extends RecipeField {
  const ChoiceField({
    required super.id,
    required super.label,
    required super.prop,
    required this.choices,
  });

  /// (카메라 코드, 보이는 이름).
  final List<(int, String)> choices;

  @override
  double? decode(int raw) =>
      choices.any((c) => c.$1 == raw) ? raw.toDouble() : null;

  @override
  int encode(double value) => value.toInt();

  @override
  bool accepts(double value) =>
      value == value.roundToDouble() && choices.any((c) => c.$1 == value);

  @override
  String display(double value) =>
      choices.firstWhere((c) => c.$1 == value, orElse: () => (0, '?')).$2;
}

/// 눈금 값. 카메라 값은 레시피 값 × [multiplier] 를 int16 으로 쓴 것이다.
final class ScaleField extends RecipeField {
  const ScaleField({
    required super.id,
    required super.label,
    required super.prop,
    required this.min,
    required this.max,
    required this.step,
    this.multiplier = 1,
    this.unit = '',
  });

  final double min;
  final double max;
  final double step;
  final int multiplier;

  /// 비어 있으면 부호 붙은 숫자(`+1.5`), 아니면 정수 뒤에 붙인다(`5500K`).
  final String unit;

  /// ×10 속성에서 "값 없음"을 뜻하는 카메라 값.
  static const _sentinel = 0x8000;

  @override
  double? decode(int raw) {
    if (multiplier != 1 && raw == _sentinel) return null;
    final signed = raw >= 0x8000 ? raw - 0x10000 : raw;
    final value = signed / multiplier;
    return accepts(value) ? value : null;
  }

  @override
  int encode(double value) => (value * multiplier).round() & 0xFFFF;

  @override
  bool accepts(double value) =>
      value >= min &&
      value <= max &&
      snapToStep(value, min: min, max: max, step: step) == value;

  @override
  String display(double value) =>
      unit.isEmpty ? formatSigned(value) : '${value.toInt()}$unit';
}

/// 카메라 값이 비선형 표로 정해진 눈금 값 (고감도 NR).
final class TableField extends RecipeField {
  const TableField({
    required super.id,
    required super.label,
    required super.prop,
    required this.table,
  });

  /// 카메라 값 → 레시피 값.
  final Map<int, int> table;

  double get min => table.values.reduce((a, b) => a < b ? a : b).toDouble();
  double get max => table.values.reduce((a, b) => a > b ? a : b).toDouble();
  double get step => 1;

  @override
  double? decode(int raw) => table[raw]?.toDouble();

  @override
  int encode(double value) =>
      table.entries.firstWhere((e) => e.value == value).key;

  @override
  bool accepts(double value) =>
      value == value.roundToDouble() && table.containsValue(value.toInt());

  @override
  String display(double value) => formatSigned(value);
}

/// WB 모드 중 색온도를 직접 정하는 값. 이때만 색온도 필드가 쓰인다.
const wbColorTemperature = 0x8007;

/// 흑백 필름 시뮬레이션 코드 (Monochrome·Sepia·Acros 계열). 컬러 대신 모노 WC·MG 를 쓴다.
const monochromeSimulations = {
  0x06,
  0x07,
  0x08,
  0x09,
  0x0A,
  0x0C,
  0x0D,
  0x0E,
  0x0F,
};

const _effects = [(1, '끔'), (2, '약'), (3, '강')];

/// 레시피 필드 표. 편집 화면과 비교 목록은 이 순서를 따른다.
/// 값과 인코딩은 FilmKit(MIT) 자료 기준이며 X-T5 에서 확인되지 않았다.
const recipeFields = <RecipeField>[
  ChoiceField(
    id: 'filmSimulation',
    label: '필름 시뮬레이션',
    prop: 0xD192,
    choices: [
      (0x01, 'Provia'),
      (0x02, 'Velvia'),
      (0x03, 'Astia'),
      (0x0B, 'Classic Chrome'),
      (0x14, 'Reala Ace'),
      (0x04, 'PRO Neg. Hi'),
      (0x05, 'PRO Neg. Std'),
      (0x11, 'Classic Neg.'),
      (0x13, 'Nostalgic Neg.'),
      (0x10, 'Eterna'),
      (0x12, 'Eterna Bleach Bypass'),
      (0x0C, 'Acros'),
      (0x0D, 'Acros + Ye'),
      (0x0E, 'Acros + R'),
      (0x0F, 'Acros + G'),
      (0x06, 'Monochrome'),
      (0x07, 'Monochrome + Ye'),
      (0x08, 'Monochrome + R'),
      (0x09, 'Monochrome + G'),
      (0x0A, 'Sepia'),
    ],
  ),
  ScaleField(
    id: 'monoWarmCool',
    label: '모노크롬 색상 WC',
    prop: 0xD193,
    min: -18,
    max: 18,
    step: 1,
    multiplier: 10,
  ),
  ScaleField(
    id: 'monoMagentaGreen',
    label: '모노크롬 색상 MG',
    prop: 0xD194,
    min: -18,
    max: 18,
    step: 1,
    multiplier: 10,
  ),
  ChoiceField(
    id: 'grain',
    label: '그레인 효과',
    prop: 0xD195,
    choices: [(1, '끔'), (2, '약·소'), (3, '강·소'), (4, '약·대'), (5, '강·대')],
  ),
  ChoiceField(
    id: 'colorChrome',
    label: '컬러 크롬 효과',
    prop: 0xD196,
    choices: _effects,
  ),
  ChoiceField(
    id: 'colorChromeFxBlue',
    label: '컬러크롬 FX 블루',
    prop: 0xD197,
    choices: _effects,
  ),
  ChoiceField(
    id: 'smoothSkin',
    label: '피부 보정 효과',
    prop: 0xD198,
    choices: _effects,
  ),
  ChoiceField(
    id: 'whiteBalance',
    label: '화이트밸런스',
    prop: 0xD199,
    choices: [
      (0x0002, '오토'),
      (0x8021, '주변광 우선'),
      (0x0004, '맑음'),
      (0x8006, '그늘'),
      (0x8001, '형광등 1'),
      (0x8002, '형광등 2'),
      (0x8003, '형광등 3'),
      (0x0006, '백열등'),
      (0x0008, '수중'),
      (wbColorTemperature, '색온도'),
    ],
  ),
  ScaleField(
    id: 'colorTemperature',
    label: '색온도',
    prop: 0xD19C,
    min: 2500,
    max: 10000,
    step: 10,
    unit: 'K',
  ),
  ScaleField(
    id: 'wbShiftRed',
    label: 'WB 시프트 R',
    prop: 0xD19A,
    min: -9,
    max: 9,
    step: 1,
  ),
  ScaleField(
    id: 'wbShiftBlue',
    label: 'WB 시프트 B',
    prop: 0xD19B,
    min: -9,
    max: 9,
    step: 1,
  ),
  ChoiceField(
    id: 'dynamicRange',
    label: '다이내믹 레인지',
    prop: 0xD190,
    choices: [(100, 'DR100'), (200, 'DR200'), (400, 'DR400')],
  ),
  ScaleField(
    id: 'highlight',
    label: '하이라이트',
    prop: 0xD19D,
    min: -2,
    max: 4,
    step: 0.5,
    multiplier: 10,
  ),
  ScaleField(
    id: 'shadow',
    label: '섀도우',
    prop: 0xD19E,
    min: -2,
    max: 4,
    step: 0.5,
    multiplier: 10,
  ),
  ScaleField(
    id: 'color',
    label: '색농도',
    prop: 0xD19F,
    min: -4,
    max: 4,
    step: 1,
    multiplier: 10,
  ),
  ScaleField(
    id: 'sharpness',
    label: '샤프니스',
    prop: 0xD1A0,
    min: -4,
    max: 4,
    step: 1,
    multiplier: 10,
  ),
  TableField(
    id: 'noiseReduction',
    label: '고감도 노이즈 감소',
    prop: 0xD1A1,
    table: {
      0x8000: -4,
      0x7000: -3,
      0x4000: -2,
      0x3000: -1,
      0x2000: 0,
      0x1000: 1,
      0x0000: 2,
      0x6000: 3,
      0x5000: 4,
    },
  ),
  ScaleField(
    id: 'clarity',
    label: '선명도',
    prop: 0xD1A2,
    min: -5,
    max: 5,
    step: 1,
    multiplier: 10,
  ),
];

final fieldById = {for (final field in recipeFields) field.id: field};

bool isMonochrome(Map<String, double> values) =>
    monochromeSimulations.contains(values['filmSimulation']?.toInt());

/// [field] 가 [values] 의 필름 시뮬레이션·WB 에서 의미가 있는지.
/// 색온도는 WB 가 색온도일 때만, 컬러는 컬러 시뮬레이션일 때만, 모노 WC·MG 는 흑백일 때만.
bool isApplicable(RecipeField field, Map<String, double> values) =>
    switch (field.id) {
      'colorTemperature' => values['whiteBalance'] == wbColorTemperature,
      'color' => !isMonochrome(values),
      'monoWarmCool' || 'monoMagentaGreen' => isMonochrome(values),
      _ => true,
    };
