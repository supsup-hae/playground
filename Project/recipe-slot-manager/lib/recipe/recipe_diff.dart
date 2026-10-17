import 'package:recipe_slot_manager/recipe/recipe_fields.dart';

/// 비교 화면의 한 줄: 필드와, 사람이 읽는 이전·이후 값.
final class FieldChange {
  const FieldChange(this.field, this.before, this.after);

  final RecipeField field;

  /// 현재 값을 모르면 `모름`.
  final String before;
  final String after;
}

/// [target] 에 값이 있고 [current] 와 다른 필드를 필드 표 순서로 돌려준다.
/// 바뀐 뒤의 필름 시뮬레이션·WB 에서 의미 없는 필드는 뺀다.
List<FieldChange> diffValues(
  Map<String, double> current,
  Map<String, double> target,
) {
  final effective = {...current, ...target};
  return [
    for (final field in recipeFields)
      if (target[field.id] case final after?)
        if (isApplicable(field, effective) && current[field.id] != after)
          FieldChange(field, switch (current[field.id]) {
            final before? => field.display(before),
            null => '모름',
          }, field.display(after)),
  ];
}
