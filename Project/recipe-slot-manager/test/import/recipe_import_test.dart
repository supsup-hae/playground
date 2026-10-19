import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/import/recipe_import.dart';

void main() {
  group('acceptedValues', () {
    test('필드 표에 없거나 범위·선택지 밖인 값은 뺀다', () {
      final values = acceptedValues({
        'highlight': 1.5,
        'shadow': 9,
        'grain': 7,
        'unknown': 1,
      });

      expect(values, {'highlight': 1.5});
    });

    test('흑백 시뮬레이션이면 컬러를 빼고 모노 WC 를 남긴다', () {
      final values = acceptedValues({
        'filmSimulation': 0x0C,
        'color': 2,
        'monoWarmCool': 3,
      });

      expect(values, {'filmSimulation': 0x0C, 'monoWarmCool': 3});
    });
  });

  test('importedRecipe 는 걸러낸 값으로 새 레시피를 만들고 읽은 항목 수를 안내한다', () {
    final imported = importedRecipe(
      name: 'Kodak',
      values: {'highlight': 1, 'shadow': 99},
      source: ImportSource.exif,
    );

    expect(imported.recipe.name, 'Kodak');
    expect(imported.recipe.values, {'highlight': 1});
    expect(imported.recipe.id, hasLength(32));
    expect(imported.note, 'EXIF에서 1개 항목을 가져왔습니다. 빈칸은 카메라 설정을 유지합니다');
  });

  test('이름이 비어 있으면 출처 이름을 쓴다', () {
    final imported = importedRecipe(
      name: '  ',
      values: const {},
      source: ImportSource.text,
    );

    expect(imported.recipe.name, '가져온 레시피 (이미지 텍스트)');
  });
}
