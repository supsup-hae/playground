import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/library/loadout.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';

void main() {
  late Directory root;
  late DateTime now;

  LibraryStore newStore() => LibraryStore(root, clock: () => now);

  Recipe recipe(String id, String name, {DateTime? at}) => Recipe(
    id: id,
    name: name,
    values: const {'highlight': 1},
    updatedAt: at ?? DateTime.utc(2026),
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('library_store_test');
    now = DateTime.utc(2026, 10, 17, 9);
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('Loadout', () {
    test('JSON 왕복 변환된다', () {
      final loadout = Loadout(
        id: 'l1',
        name: '야간 거리',
        slots: const ['r1', null, null, 'r2', null, null, null],
        updatedAt: now,
      );

      expect(Loadout.fromJson(loadout.toJson()).toJson(), loadout.toJson());
    });

    test('슬롯이 7칸이 아니면 FormatException', () {
      final json = {
        'id': 'l1',
        'name': 'x',
        'slots': [null, null],
        'updatedAt': now.toIso8601String(),
        'deletedAt': null,
      };
      expect(() => Loadout.fromJson(json), throwsFormatException);
    });

    test('슬롯에 문자열·null 이 아닌 값이 있으면 FormatException', () {
      final json = {
        'id': 'l1',
        'name': 'x',
        'slots': [1, null, null, null, null, null, null],
        'updatedAt': now.toIso8601String(),
        'deletedAt': null,
      };
      expect(() => Loadout.fromJson(json), throwsFormatException);
    });
  });

  test('저장한 레시피·묶음을 새 저장소에서 그대로 불러오고, 저장 시각을 찍는다', () async {
    final store = newStore();
    await store.load();
    await store.saveRecipe(recipe('r1', 'Kodak'));
    await store.saveLoadout(
      Loadout(
        id: 'l1',
        name: '여행',
        slots: const ['r1', null, null, null, null, null, null],
        updatedAt: DateTime.utc(2000),
      ),
    );

    final reloaded = newStore();
    await reloaded.load();

    expect(reloaded.recipes.single.name, 'Kodak');
    expect(reloaded.recipes.single.updatedAt, now);
    expect(reloaded.loadouts.single.slots.first, 'r1');
    expect(reloaded.loadouts.single.updatedAt, now);
  });

  test('레시피는 이름순이고, 삭제한 것은 목록에서 빠지지만 동기화용으로 남는다', () async {
    final store = newStore();
    await store.load();
    await store.saveRecipe(recipe('r2', 'Velvia'));
    await store.saveRecipe(recipe('r1', 'Acros'));
    await store.deleteRecipe('r2');

    expect(store.recipes.map((r) => r.name), ['Acros']);
    expect(store.allRecipes.firstWhere((r) => r.id == 'r2').deletedAt, now);
  });

  test('묶음이 삭제된 레시피를 가리키면 그 칸은 비어 있다', () async {
    final store = newStore();
    await store.load();
    await store.saveRecipe(recipe('r1', 'Kodak'));
    final loadout = Loadout(
      id: 'l1',
      name: '여행',
      slots: const ['r1', 'missing', null, null, null, null, null],
      updatedAt: now,
    );
    await store.deleteRecipe('r1');

    expect(store.slotRecipes(loadout), everyElement(isNull));
  });

  test('저장하면 듣는 쪽에 알린다', () async {
    final store = newStore();
    await store.load();
    var notified = 0;
    store.addListener(() => notified++);

    await store.saveRecipe(recipe('r1', 'Kodak'));

    expect(notified, 1);
  });

  test('깨진 파일은 덮어쓰지 않고 옮겨 두며, 다른 파일은 그대로 읽는다', () async {
    final first = newStore();
    await first.load();
    await first.saveLoadout(
      Loadout(
        id: 'l1',
        name: '여행',
        slots: const [null, null, null, null, null, null, null],
        updatedAt: now,
      ),
    );
    File(p.join(root.path, 'recipes.json')).writeAsStringSync('{"recipes": 1}');

    final store = newStore();
    await store.load();
    await store.saveRecipe(recipe('r1', 'New'));

    expect(store.loadErrors.single, contains('recipes.json'));
    expect(store.loadouts.single.name, '여행');
    final quarantined = root
        .listSync()
        .map((e) => p.basename(e.path))
        .where((n) => n.startsWith('recipes.json.corrupt-'));
    expect(quarantined, hasLength(1));
    final kept = File(p.join(root.path, quarantined.single)).readAsStringSync();
    expect(kept, '{"recipes": 1}');
  });

  test('같은 파일에 동시에 저장해도 둘 다 끝나고 파일은 마지막 상태다', () async {
    final store = newStore();
    await store.load();

    await Future.wait([
      store.saveRecipe(recipe('r1', 'One')),
      store.saveRecipe(recipe('r2', 'Two')),
    ]);

    final reloaded = newStore();
    await reloaded.load();
    expect(reloaded.recipes.map((r) => r.name), ['One', 'Two']);
  });

  group('mergeRemote', () {
    test('id 별로 updatedAt 이 늦은 쪽을 남기고, 원격 삭제도 반영한다', () async {
      final store = newStore();
      await store.load();
      now = DateTime.utc(2026, 10, 17, 10);
      await store.saveRecipe(recipe('local-newer', 'Local'));
      now = DateTime.utc(2026, 10, 17, 8);
      await store.saveRecipe(recipe('remote-newer', 'Old'));
      await store.saveRecipe(recipe('deleted-remotely', 'Gone'));

      final changed = await store.mergeRemote(
        recipes: [
          recipe('local-newer', 'Remote', at: DateTime.utc(2026, 10, 17, 9)),
          recipe('remote-newer', 'New', at: DateTime.utc(2026, 10, 17, 9)),
          recipe(
            'deleted-remotely',
            'Gone',
            at: DateTime.utc(2026, 10, 17, 9),
          ).markDeleted(DateTime.utc(2026, 10, 17, 9)),
          recipe('brand-new', 'Fresh', at: DateTime.utc(2026, 10, 17, 9)),
        ],
        loadouts: const [],
      );

      expect(changed, 3);
      expect(store.recipes.map((r) => r.name), ['Fresh', 'Local', 'New']);
      final reloaded = newStore();
      await reloaded.load();
      expect(reloaded.recipes.map((r) => r.name), ['Fresh', 'Local', 'New']);
    });
  });
}
