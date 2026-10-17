import 'dart:typed_data';

import 'package:recipe_slot_manager/camera/prop_value.dart';
import 'package:recipe_slot_manager/camera/slot_snapshot.dart';
import 'package:recipe_slot_manager/ptp/ptp_string.dart';
import 'package:recipe_slot_manager/recipe/recipe_fields.dart';

/// 슬롯 속성을 레시피 값으로 바꾼다. 해석할 수 없는 값과, 지금 필름 시뮬레이션·WB 에서
/// 의미 없는 필드는 빠진다 (빠진 필드는 "카메라 값 유지").
Map<String, double> decodeSlot(SlotSnapshot slot) {
  final all = <String, double>{
    for (final field in recipeFields)
      if (_rawOf(slot, field.prop) case final raw?)
        field.id: ?field.decode(raw),
  };
  return {
    for (final MapEntry(:key, :value) in all.entries)
      if (isApplicable(fieldById[key]!, all)) key: value,
  };
}

/// [base] 슬롯의 속성을 복사하고, [values] 에 있는 필드만 덮어쓴 슬롯을 만든다.
///
/// 카메라가 받아들이지 않는 값은 쓰지 않는다: 의미 없는 필드(조건은 [isApplicable]),
/// 0 인 모노 WC·MG, [base] 에 없는 속성. [name] 이 비어 있으면 [base] 이름을 쓴다.
/// 필드 표의 범위·선택지에 맞지 않는 값이나 254자를 넘는 이름은 [FormatException] 이다.
SlotSnapshot encodeValues(
  String name,
  Map<String, double> values, {
  required SlotSnapshot base,
}) {
  if (name.length > maxPtpStringLength) {
    throw FormatException('레시피 이름이 $maxPtpStringLength자를 넘는다', name);
  }
  final effective = {...decodeSlot(base), ...values};
  final props = Map<int, Uint8List>.of(base.props);
  for (final field in recipeFields) {
    final value = values[field.id];
    if (value == null || !props.containsKey(field.prop)) continue;
    if (!field.accepts(value)) {
      throw FormatException('${field.label} 값이 맞지 않다', value);
    }
    if (!isApplicable(field, effective)) continue;
    if (field.id.startsWith('mono') && value == 0) continue;
    props[field.prop] = encodePropValue(field.encode(value), 2)!;
  }
  return SlotSnapshot(
    slot: base.slot,
    name: name.isEmpty ? base.name : name,
    props: props,
  );
}

int? _rawOf(SlotSnapshot slot, int prop) {
  final bytes = slot.props[prop];
  if (bytes == null || bytes.length != 2) return null;
  return ByteData.sublistView(bytes).getUint16(0, Endian.little);
}
