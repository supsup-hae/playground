/// [value] 를 [step] 배수로 반올림하고 [min]–[max] 로 자른다. 결과에서 부동소수 오차를 없앤다.
double snapToStep(
  double value, {
  required double min,
  required double max,
  required double step,
}) {
  final snapped = (min + ((value - min) / step).round() * step).clamp(min, max);
  return double.parse(snapped.toStringAsFixed(_decimals(step)));
}

int _decimals(double step) {
  final text = step.toString();
  final dot = text.indexOf('.');
  if (dot < 0) return 0;
  return text.substring(dot + 1).replaceAll(RegExp(r'0+$'), '').length;
}

/// 0보다 크면 `+` 를 붙이고, 정수면 소수점을 떼어 보여 준다 (`+1.5`, `-1`, `0`).
String formatSigned(double value) {
  final text = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
  return value > 0 ? '+$text' : text;
}
