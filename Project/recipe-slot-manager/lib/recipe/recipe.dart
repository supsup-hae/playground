import 'dart:math';

import 'package:recipe_slot_manager/ptp/ptp_string.dart';
import 'package:recipe_slot_manager/recipe/recipe_fields.dart';

/// 보관함의 레시피 하나. [values] 에 없는 필드는 카메라 값을 그대로 둔다.
final class Recipe {
  Recipe({
    required this.id,
    required this.name,
    List<String> tags = const [],
    required Map<String, double> values,
    required this.updatedAt,
    this.deletedAt,
  }) : tags = List.unmodifiable(tags),
       values = Map.unmodifiable(values);

  /// 파일·동기화로 들어온 JSON 을 읽는다. 필드 표에 없는 필드, 범위·간격·선택지에 맞지 않는
  /// 값, 254자를 넘는 이름은 [FormatException] 이다.
  factory Recipe.fromJson(Object? json) {
    if (json
        case {
          'id': final String id,
          'name': final String name,
          'tags': final List<dynamic> tags,
          'values': final Map<String, dynamic> values,
          'updatedAt': final String updatedAt,
        }
        when id.isNotEmpty &&
            name.length <= maxPtpStringLength &&
            tags.every((t) => t is String)) {
      return Recipe(
        id: id,
        name: name,
        tags: tags.cast<String>(),
        values: _parseValues(values),
        updatedAt: parseUtc(updatedAt),
        deletedAt: switch (json['deletedAt']) {
          null => null,
          final String text => parseUtc(text),
          final other => throw FormatException('deletedAt 형식이 맞지 않다', other),
        },
      );
    }
    throw FormatException('레시피 형식이 맞지 않다', json);
  }

  /// 32자 16진수.
  final String id;
  final String name;
  final List<String> tags;

  /// 필드 id → 레시피 값.
  final Map<String, double> values;
  final DateTime updatedAt;

  /// 삭제한 시각. 동기화 때 다른 기기에도 삭제를 알리려고 행을 남긴다.
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Recipe copyWith({
    String? name,
    List<String>? tags,
    Map<String, double>? values,
    required DateTime updatedAt,
  }) => Recipe(
    id: id,
    name: name ?? this.name,
    tags: tags ?? this.tags,
    values: values ?? this.values,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );

  Recipe markDeleted(DateTime now) => Recipe(
    id: id,
    name: name,
    tags: tags,
    values: values,
    updatedAt: now,
    deletedAt: now,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tags': tags,
    'values': values,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };
}

/// 레시피·묶음 id. 무작위 16바이트를 16진수 32자로.
String newRecipeId() {
  final random = Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// ISO 8601 문자열을 UTC 시각으로. 형식이 아니면 [FormatException].
DateTime parseUtc(String text) =>
    (DateTime.tryParse(text) ?? (throw FormatException('날짜 형식이 맞지 않다', text)))
        .toUtc();

Map<String, double> _parseValues(Map<String, dynamic> json) => {
  for (final MapEntry(:key, :value) in json.entries)
    key: switch ((fieldById[key], value)) {
      (final field?, final num number) when field.accepts(number.toDouble()) =>
        number.toDouble(),
      _ => throw FormatException('레시피 값이 맞지 않다: $key', value),
    },
};
