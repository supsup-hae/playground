import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';
import 'package:recipe_slot_manager/recipe/recipe_diff.dart';

void main() {
  final updatedAt = DateTime.utc(2026, 10, 17, 9);
  final recipe = Recipe(
    id: 'a' * 32,
    name: '야간 거리',
    tags: const ['야간', '스트리트'],
    values: const {'filmSimulation': 0x13, 'highlight': 1.5, 'grain': 4},
    updatedAt: updatedAt,
  );

  group('Recipe JSON', () {
    test('왕복 변환된다', () {
      final restored = Recipe.fromJson(recipe.toJson());

      expect(restored.toJson(), recipe.toJson());
      expect(restored.updatedAt, updatedAt);
      expect(restored.deletedAt, isNull);
    });

    for (final (label, patch) in <(String, Map<String, Object?>)>[
      (
        '범위 밖 값',
        {
          'values': {'highlight': 9},
        },
      ),
      (
        '간격에 맞지 않는 값',
        {
          'values': {'highlight': 0.3},
        },
      ),
      (
        '목록에 없는 선택지',
        {
          'values': {'grain': 7},
        },
      ),
      (
        '모르는 필드',
        {
          'values': {'iso': 400},
        },
      ),
      ('id 없음', {'id': ''}),
      ('이름이 PTP 한도 초과', {'name': 'a' * 255}),
      (
        '태그가 문자열 목록이 아님',
        {
          'tags': [1],
        },
      ),
      ('날짜 형식 아님', {'updatedAt': 'yesterday'}),
    ]) {
      test('$label 이면 FormatException', () {
        final json = {...recipe.toJson(), ...patch};
        expect(() => Recipe.fromJson(json), throwsFormatException);
      });
    }
  });

  test('newRecipeId 는 32자 16진수이고 겹치지 않는다', () {
    final ids = {for (var i = 0; i < 100; i++) newRecipeId()};

    expect(ids, hasLength(100));
    expect(ids.every(RegExp(r'^[0-9a-f]{32}$').hasMatch), isTrue);
  });

  group('diffValues', () {
    test('같은 값이면 바뀐 필드가 없다', () {
      expect(diffValues(recipe.values, recipe.values), isEmpty);
    });

    test('바뀐 필드만 필드 표 순서로, 사람이 읽는 값으로 돌려준다', () {
      final changes = diffValues({
        'filmSimulation': 0x11,
        'highlight': -1,
        'grain': 4,
      }, recipe.values);

      expect(changes.map((c) => (c.field.id, c.before, c.after)), [
        ('filmSimulation', 'Classic Neg.', 'Nostalgic Neg.'),
        ('highlight', '-1', '+1.5'),
      ]);
    });

    test('대상에 값이 없는 필드는 바꾸지 않는 것으로 보고, 현재 값을 모르면 "모름"', () {
      final changes = diffValues({'color': 2}, {'highlight': 0});

      expect(changes.map((c) => (c.field.id, c.before, c.after)), [
        ('highlight', '모름', '0'),
      ]);
    });
  });
}
