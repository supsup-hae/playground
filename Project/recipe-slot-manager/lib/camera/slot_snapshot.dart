import 'dart:typed_data';

import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/ptp/ptp_string.dart';

/// 커스텀 슬롯 하나의 이름과 속성별 원시 값.
final class SlotSnapshot {
  SlotSnapshot({
    required this.slot,
    required this.name,
    required Map<int, Uint8List> props,
  }) : props = Map.unmodifiable(props);

  /// 백업 파일에서 읽는다. 카메라에 그대로 쓰이므로 슬롯 번호(1–7), 이름 길이,
  /// 속성 코드(레시피 범위), 값(짝수 길이 16진수)이 맞지 않으면 [FormatException] 을 던진다.
  factory SlotSnapshot.fromJson(Object? json) {
    if (json
        case {
          'slot': final int slot,
          'name': final String name,
          'props': final Map<String, dynamic> props,
        }
        when slot >= 1 &&
            slot <= FujiProp.slotCount &&
            name.length <= maxPtpStringLength) {
      return SlotSnapshot(
        slot: slot,
        name: name,
        props: {
          for (final MapEntry(:key, :value) in props.entries)
            _propCode(key): _fromHex(value),
        },
      );
    }
    throw FormatException('사용자 설정 형식 오류', json);
  }

  /// 1–7.
  final int slot;
  final String name;

  /// 속성 코드 → 카메라가 돌려준 값 바이트.
  final Map<int, Uint8List> props;

  SlotSnapshot copyWith({String? name, Map<int, Uint8List>? props}) =>
      SlotSnapshot(
        slot: slot,
        name: name ?? this.name,
        props: props ?? this.props,
      );

  Map<String, dynamic> toJson() => {
    'slot': slot,
    'name': name,
    'props': {
      for (final MapEntry(:key, :value) in props.entries)
        propLabel(key): _toHex(value),
    },
  };
}

String _toHex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

final _hexBytes = RegExp(r'^(?:[0-9a-fA-F]{2})+$');
final _hexCode = RegExp(r'^[0-9a-fA-F]{4}$');

int _propCode(String key) {
  final code = _hexCode.hasMatch(key) ? int.parse(key, radix: 16) : null;
  if (code == null ||
      code < FujiProp.presetFirst ||
      code > FujiProp.presetLast) {
    throw FormatException('레시피 속성 코드 아님', key);
  }
  return code;
}

Uint8List _fromHex(Object? hex) {
  if (hex is! String || !_hexBytes.hasMatch(hex)) {
    throw FormatException('속성 값이 짝수 길이 16진수 아님', hex);
  }
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}
