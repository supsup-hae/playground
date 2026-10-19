import 'package:recipe_slot_manager/recipe/recipe.dart';
import 'package:recipe_slot_manager/recipe/recipe_fields.dart';

/// 레시피를 가져온 곳.
enum ImportSource {
  cameraSlot('카메라 사용자 설정'),
  exif('EXIF'),
  text('이미지 텍스트');

  const ImportSource(this.label);

  final String label;
}

/// 가져오기 실패. 화면은 [message] 를 그대로 보인다.
final class ImportException implements Exception {
  const ImportException(this.message);

  final String message;

  @override
  String toString() => 'ImportException: $message';
}

/// 필드 표에 있고 범위·선택지 안이며, 지금 필름 시뮬레이션에서 의미 있는 값만 남긴다.
Map<String, double> acceptedValues(Map<String, double> values) {
  final known = {
    for (final MapEntry(:key, :value) in values.entries)
      if (fieldById[key]?.accepts(value) ?? false) key: value,
  };
  return {
    for (final MapEntry(:key, :value) in known.entries)
      if (isApplicable(fieldById[key]!, known)) key: value,
  };
}

/// 아직 저장하지 않은 새 레시피와 편집 화면에 보일 안내 문구.
typedef ImportedRecipe = ({Recipe recipe, String note});

/// 가져온 값으로 [ImportedRecipe] 를 만든다.
ImportedRecipe importedRecipe({
  required String name,
  required Map<String, double> values,
  required ImportSource source,
}) {
  final accepted = acceptedValues(values);
  final trimmed = name.trim();
  return (
    recipe: Recipe(
      id: newRecipeId(),
      name: trimmed.isEmpty ? '가져온 레시피 (${source.label})' : trimmed,
      values: accepted,
      updatedAt: DateTime.now().toUtc(),
    ),
    note:
        '${source.label}에서 ${accepted.length}개 항목을 가져왔습니다. '
        '빈칸은 카메라 설정을 유지합니다',
  );
}
