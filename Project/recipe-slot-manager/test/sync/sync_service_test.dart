import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/library/loadout.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';
import 'package:recipe_slot_manager/sync/remote_library.dart';
import 'package:recipe_slot_manager/sync/sync_service.dart';

/// 올린 행을 기록하고, 정해 둔 원격 행을 돌려주는 가짜 원격 보관함.
class FakeRemote implements RemoteLibrary {
  final uploadedRecipes = <List<String>>[];
  final uploadedLoadouts = <List<String>>[];
  final fetchedSince = <DateTime?>[];
  var recipeRows = <Object?>[];
  var loadoutRows = <Object?>[];
  Exception? failure;

  @override
  Future<RemoteChanges> fetchSince(DateTime? since) async {
    if (failure case final error?) throw error;
    fetchedSince.add(since);
    return RemoteChanges(recipes: recipeRows, loadouts: loadoutRows);
  }

  @override
  Future<void> upsert({
    required List<Recipe> recipes,
    required List<Loadout> loadouts,
  }) async {
    if (failure case final error?) throw error;
    uploadedRecipes.add([for (final r in recipes) r.id]);
    uploadedLoadouts.add([for (final l in loadouts) l.id]);
  }
}

void main() {
  late Directory root;
  late DateTime now;
  late LibraryStore library;
  late FakeRemote remote;
  late CameraLog log;

  SyncService newService() => SyncService(
    library: library,
    remote: remote,
    log: log,
    stateFile: File(p.join(root.path, 'sync.json')),
    clock: () => now,
  );

  Recipe recipe(String id, String name, DateTime at) =>
      Recipe(id: id, name: name, values: const {'highlight': 1}, updatedAt: at);

  setUp(() async {
    root = Directory.systemTemp.createTempSync('sync_service_test');
    now = DateTime.utc(2026, 10, 17, 9);
    library = LibraryStore(
      Directory(p.join(root.path, 'library')),
      clock: () => now,
    );
    await library.load();
    remote = FakeRemote();
    log = CameraLog();
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('처음 동기화는 로컬 행을 모두 올리고, 원격 행을 합치고, 시각을 남긴다', () async {
    await library.saveRecipe(recipe('a' * 32, 'Local', now));
    remote.recipeRows = [
      recipe('b' * 32, 'Remote', DateTime.utc(2026, 10, 17, 8)).toJson(),
    ];
    final service = newService();
    await service.loadState();

    expect(await service.sync(), isTrue);

    expect(remote.uploadedRecipes.single, ['a' * 32]);
    expect(remote.fetchedSince.single, isNull);
    expect(library.recipes.map((r) => r.name), ['Local', 'Remote']);
    expect(service.lastSyncAt, now);
    final reloaded = newService();
    await reloaded.loadState();
    expect(reloaded.lastSyncAt, now);
  });

  test('다음 동기화는 마지막 동기화 이후 바뀐 행만 올리고 그 이후만 받는다', () async {
    await library.saveRecipe(recipe('a' * 32, 'Old', now));
    final service = newService();
    await service.loadState();
    await service.sync();
    final firstSync = now;

    now = now.add(const Duration(minutes: 5));
    await library.saveRecipe(recipe('c' * 32, 'New', now));
    await service.sync();

    expect(remote.uploadedRecipes.last, ['c' * 32]);
    expect(remote.fetchedSince.last, firstSync);
  });

  test('형식이 맞지 않는 원격 행은 건너뛰고 나머지를 합친다', () async {
    remote.recipeRows = [
      {'broken': true},
      recipe('b' * 32, 'Remote', now).toJson(),
    ];
    remote.loadoutRows = [
      {'slots': []},
    ];
    final service = newService();

    expect(await service.sync(), isTrue);

    expect(library.recipes.single.name, 'Remote');
    expect(log.entries.last.$2, contains('건너뜀 2'));
  });

  test('원격에 닿지 못하면 기기 데이터와 동기화 시각은 그대로 두고 로그에 남긴다', () async {
    await library.saveRecipe(recipe('a' * 32, 'Local', now));
    remote.failure = const SocketException('offline');
    final service = newService();

    expect(await service.sync(), isFalse);

    expect(library.recipes.single.name, 'Local');
    expect(service.lastSyncAt, isNull);
    expect(log.entries.last.$2, startsWith('동기화 실패'));
  });
}
