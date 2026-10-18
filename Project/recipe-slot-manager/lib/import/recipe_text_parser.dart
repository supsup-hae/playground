/// OCR 로 읽은 글자 줄에서 레시피 값을 찾는다. 영어(레시피 사이트 카드)와 한국어(SNS)
/// 이름을 읽고, 한 줄에 여러 항목이 있어도 된다. 읽지 못한 항목은 빠진다.
///
/// 돌려주는 값은 읽은 그대로라서 범위·선택지 검사는 하지 않는다 (`acceptedValues` 가 한다).
Map<String, double> parseRecipeText(List<String> lines) {
  // 이름 뒤에 `:` 가 붙은 항목을 먼저 쓴다. 제목 줄의 낱말("Color Recipe 2")은 밀린다.
  final explicit = <String, double>{};
  final loose = <String, double>{};
  for (final line in lines) {
    for (final segment in _normalize(line).split(RegExp(r'[/|]'))) {
      for (final (key, text) in _labelled(segment)) {
        final target = text.trimLeft().startsWith(':') ? explicit : loose;
        for (final MapEntry(key: id, :value) in _readValue(key, text).entries) {
          target.putIfAbsent(id, () => value);
        }
      }
    }
  }
  return {...loose, ...explicit};
}

/// 항목 이름 별칭 → 필드 id. `wbShift`·`mono` 는 두 필드를 함께 읽는 이름이다.
const _labels = {
  'filmSimulation': [
    'film simulation',
    'film sim',
    'simulation',
    '필름 시뮬레이션',
    '필름시뮬레이션',
    '필름 시뮬',
  ],
  'grain': ['grain effect', 'grain', '그레인 효과', '그레인'],
  'colorChromeFxBlue': [
    'color chrome fx blue',
    'colour chrome fx blue',
    'color chrome effect blue',
    'color chrome blue',
    'fx blue',
    '컬러 크롬 fx 블루',
    '컬러크롬 fx 블루',
    '컬러 크롬 블루',
    '컬러크롬 블루',
  ],
  'colorChrome': [
    'color chrome effect',
    'colour chrome effect',
    'color chrome',
    'colour chrome',
    '컬러 크롬 효과',
    '컬러 크롬',
    '컬러크롬',
  ],
  'smoothSkin': ['smooth skin effect', 'smooth skin', '스무스 스킨'],
  'whiteBalance': ['white balance', 'wb', '화이트 밸런스', '화이트밸런스'],
  'wbShift': ['white balance shift', 'wb shift', '화이트 밸런스 시프트'],
  'dynamicRange': [
    'dynamic range',
    'd-range',
    'dr',
    '다이내믹 레인지',
    '다이나믹 레인지',
    '다이내믹레인지',
    '다이나믹레인지',
  ],
  'highlight': [
    'highlight tone',
    'highlights',
    'highlight',
    '하이라이트 톤',
    '하이라이트',
  ],
  'shadow': [
    'shadow tone',
    'shadows',
    'shadow',
    '섀도 톤',
    '섀도우',
    '섀도',
    '쉐도우',
    '쉐도',
  ],
  'color': ['color', 'colour', 'saturation', '컬러', '색농도', '채도'],
  'sharpness': ['sharpness', 'sharpening', '샤프니스', '선명도'],
  'noiseReduction': [
    'high iso noise reduction',
    'high iso nr',
    'noise reduction',
    'nr',
    '고감도 nr',
    '노이즈 리덕션',
    '노이즈 감소',
    '노이즈',
  ],
  'clarity': ['clarity', '클래리티', '명료도'],
  'mono': [
    'monochromatic color',
    'monochrome color',
    'mono color',
    '모노크롬 컬러',
    '모노 컬러',
  ],
};

/// 긴 별칭부터 맞춰 본다 ("color chrome" 이 "color" 보다 먼저).
final _aliases = [
  for (final MapEntry(:key, :value) in _labels.entries)
    for (final alias in value) (alias, key),
]..sort((a, b) => b.$1.length.compareTo(a.$1.length));

String _normalize(String line) => line
    .toLowerCase()
    .replaceAll(RegExp('[−–—]'), '-')
    .replaceAll('＋', '+')
    .replaceAll('：', ':');

bool _isLatin(String char) => RegExp('[a-z]').hasMatch(char);

/// [segment] 에서 항목 이름을 찾아 (필드 id, 다음 이름 전까지의 값 글자) 로 나눈다.
List<(String, String)> _labelled(String segment) {
  final found = <(int, int, String)>[];
  var i = 0;
  while (i < segment.length) {
    final match = _aliases.where((a) => _labelAt(segment, i, a.$1)).firstOrNull;
    if (match == null) {
      i++;
      continue;
    }
    found.add((i, i + match.$1.length, match.$2));
    i += match.$1.length;
  }
  return [
    for (var n = 0; n < found.length; n++)
      (
        found[n].$3,
        segment.substring(
          found[n].$2,
          n + 1 < found.length ? found[n + 1].$1 : segment.length,
        ),
      ),
  ];
}

/// 라틴 글자 별칭은 낱말 경계에서만 맞춘다 ("sunrise" 안의 "nr" 은 이름이 아니다).
bool _labelAt(String text, int start, String alias) {
  if (!text.startsWith(alias, start)) return false;
  final end = start + alias.length;
  if (_isLatin(alias[0]) && start > 0 && _isLatin(text[start - 1])) {
    return false;
  }
  if (_isLatin(alias[alias.length - 1]) &&
      end < text.length &&
      _isLatin(text[end])) {
    return false;
  }
  return true;
}

Map<String, double> _readValue(String key, String text) => switch (key) {
  'filmSimulation' => {key: ?_pick(text, _filmSimulations)},
  'grain' => {key: ?_grain(text)},
  'colorChrome' || 'colorChromeFxBlue' || 'smoothSkin' => {key: ?_effect(text)},
  'dynamicRange' => {key: ?_dynamicRange(text)},
  'whiteBalance' => {..._whiteBalance(text), ..._wbShift(text)},
  'wbShift' => _wbShift(text),
  'mono' => {
    'monoWarmCool': ?_after(text, r'(?:wc|warm)'),
    'monoMagentaGreen': ?_after(text, r'(?:mg|magenta)'),
  },
  _ => {key: ?_number(text)},
};

/// 숫자 자리에서 OCR 이 섞는 글자를 바로잡고 첫 부호 붙은 숫자를 읽는다.
double? _number(String text) {
  final fixed = text
      .replaceAllMapped(RegExp(r'(?<=[+\-.\d])o|o(?=[.\d])'), (_) => '0')
      .replaceAllMapped(
        RegExp(r'([+-]?)(\d*)½'),
        (m) => '${m[1]}${m[2]!.isEmpty ? '0' : m[2]}.5',
      );
  final match = RegExp(r'([+-]?)\s?(\d+(?:\.\d+)?)').firstMatch(fixed);
  if (match == null) return null;
  final number = double.parse(match[2]!);
  return match[1] == '-' ? -number : number;
}

/// [prefix] 바로 뒤의 부호 붙은 정수.
double? _after(String text, String prefix) {
  final match = RegExp('$prefix\\s*:?\\s*([+-]?\\d+)').firstMatch(text);
  return match == null ? null : double.parse(match[1]!);
}

/// [choices] 의 별칭 중 [text] 에 들어 있는 가장 긴 것의 코드.
double? _pick(String text, Map<String, int> choices) {
  final value = text
      .replaceAll('.', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s*\+\s*'), '+');
  final hits = choices.keys.where(value.contains).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return hits.isEmpty ? null : choices[hits.first]!.toDouble();
}

const _filmSimulations = {
  'provia': 0x01,
  '프로비아': 0x01,
  'velvia': 0x02,
  '벨비아': 0x02,
  'astia': 0x03,
  '아스티아': 0x03,
  'pro neg hi': 0x04,
  'pro neg high': 0x04,
  '프로 네가 하이': 0x04,
  'pro neg std': 0x05,
  'pro neg standard': 0x05,
  '프로 네가 스탠다드': 0x05,
  'monochrome': 0x06,
  '모노크롬': 0x06,
  'monochrome+ye': 0x07,
  'monochrome+y': 0x07,
  'monochrome yellow': 0x07,
  'monochrome+r': 0x08,
  'monochrome red': 0x08,
  'monochrome+g': 0x09,
  'monochrome green': 0x09,
  'sepia': 0x0A,
  '세피아': 0x0A,
  'classic chrome': 0x0B,
  '클래식 크롬': 0x0B,
  'acros': 0x0C,
  '아크로스': 0x0C,
  'acros+ye': 0x0D,
  'acros+y': 0x0D,
  'acros yellow': 0x0D,
  'acros+r': 0x0E,
  'acros red': 0x0E,
  'acros+g': 0x0F,
  'acros green': 0x0F,
  'eterna': 0x10,
  '이터나': 0x10,
  'classic negative': 0x11,
  'classic neg': 0x11,
  '클래식 네거티브': 0x11,
  '클래식 네가': 0x11,
  'eterna bleach bypass': 0x12,
  'bleach bypass': 0x12,
  '블리치 바이패스': 0x12,
  'nostalgic negative': 0x13,
  'nostalgic neg': 0x13,
  '노스탤직 네거티브': 0x13,
  '노스탤직 네가': 0x13,
  'reala ace': 0x14,
  'reala': 0x14,
  '리얼라': 0x14,
};

bool _hasAny(String text, List<String> words) => words.any(text.contains);

double? _effect(String text) {
  if (_hasAny(text, ['off', '끔', '없음', 'none'])) return 1;
  if (_hasAny(text, ['weak', 'low', '약'])) return 2;
  if (_hasAny(text, ['strong', 'high', '강'])) return 3;
  return null;
}

/// 끔 1, 약·소 2, 강·소 3, 약·대 4, 강·대 5. 크기가 없으면 작게로 본다.
double? _grain(String text) {
  if (_hasAny(text, ['off', '끔', '없음', 'none'])) return 1;
  final strong = _hasAny(text, ['strong', '강']);
  final weak = _hasAny(text, ['weak', '약']);
  if (strong == weak) return null;
  final large = _hasAny(text, ['large', 'big', '대', '크게']);
  return (strong ? 3 : 2) + (large ? 2 : 0);
}

double? _dynamicRange(String text) {
  final match = RegExp(r'(?:^|[^\d])(100|200|400)(?!\d)').firstMatch(text);
  return match == null ? null : double.parse(match[1]!);
}

const _whiteBalanceModes = {
  'auto': 0x0002,
  '오토': 0x0002,
  '자동': 0x0002,
  'ambience': 0x8021,
  '주변광': 0x8021,
  'daylight': 0x0004,
  'sunny': 0x0004,
  'fine': 0x0004,
  '맑음': 0x0004,
  '일광': 0x0004,
  'shade': 0x8006,
  'cloudy': 0x8006,
  '그늘': 0x8006,
  '흐림': 0x8006,
  'fluorescent 1': 0x8001,
  'fluorescent light 1': 0x8001,
  '형광등 1': 0x8001,
  'fluorescent 2': 0x8002,
  'fluorescent light 2': 0x8002,
  '형광등 2': 0x8002,
  'fluorescent 3': 0x8003,
  'fluorescent light 3': 0x8003,
  '형광등 3': 0x8003,
  'incandescent': 0x0006,
  'tungsten': 0x0006,
  '백열': 0x0006,
  'underwater': 0x0008,
  '수중': 0x0008,
};

/// WB 모드. 색온도(`5600K`)면 색온도 모드와 그 값. 흰색 우선 오토는 필드 표에 없어 뺀다.
Map<String, double> _whiteBalance(String text) {
  final kelvin = RegExp(r'(\d{4,5})\s*k').firstMatch(text);
  if (kelvin != null) {
    return {
      'whiteBalance': 0x8007,
      'colorTemperature': double.parse(kelvin[1]!),
    };
  }
  if (_hasAny(text, ['white priority', '화이트 우선', '흰색 우선'])) return {};
  final mode = _pick(text, _whiteBalanceModes);
  return {'whiteBalance': ?mode};
}

/// `+2 red & -4 blue`, `r+2 b-4`, `레드 +2 블루 -4`.
Map<String, double> _wbShift(String text) {
  double? shift(String names) {
    final after = RegExp('(?<![a-z])(?:$names)\\s*:?\\s*([+-]?\\d+)')
        .firstMatch(text);
    if (after != null) return double.parse(after[1]!);
    final before = RegExp('([+-]?\\d+)\\s*(?:$names)(?![a-z])')
        .firstMatch(text);
    return before == null ? null : double.parse(before[1]!);
  }

  return {
    'wbShiftRed': ?shift('red|r|레드|빨강'),
    'wbShiftBlue': ?shift('blue|b|블루|파랑'),
  };
}
