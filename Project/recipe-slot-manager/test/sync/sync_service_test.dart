import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/library/loadout.dart';
import 'package:recipe_slot_manager/photo/photo_index_store.dart';
import 'package:recipe_slot_manager/photo/place_log_store.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';
import 'package:recipe_slot_manager/sync/photo_sync.dart';
import 'package:recipe_slot_manager/sync/remote_library.dart';
import 'package:recipe_slot_manager/sync/sync_service.dart';

import 'photo_sync_test.dart' show FakeRemotePhotos;

/// id 별 body 를 들고 있는 가짜 원격 보관함. 올린 행은 그대로 저장한다.
class FakeRemote implements RemoteLibrary {
  final recipeRows = <String, Object?>{};
  final loadoutRows = <String, Object?>{};
  final uploadedRecipes = <List<String>>[];
  Exception? failure;

  @override
  Future<RemoteChanges> fetchAll() async {
    if (failure case final error?) throw error;
    return RemoteChanges(
      recipes: recipeRows.values.toList(),
      loadouts: loadoutRows.values.toList(),
    );
  }

  @override
  Future<void> upsert({
    required List<Recipe> recipes,
    required List<Loadout> loadouts,
  }) async {
    if (failure case final error?) throw error;
    uploadedRecipes.add([for (final r in recipes) r.id]);
    for (final r in recipes) {
      recipeRows[r.id] = r.toJson();
    }
    for (final l in loadouts) {
      loadoutRows[l.id] = l.toJson();
    }
  }
}

final idA = 'a' * 32;
final idB = 'b' * 32;

void main() {
  late Directory root;
  late DateTime now;
  late FakeRemote remote;

  LibraryStore newLibrary(String name) =>
      LibraryStore(Directory(p.join(root.path, name)), clock: () => now);

  SyncService newService(
    LibraryStore library, {
    CameraLog? log,
    PhotoSync? photos,
  }) => SyncService(
    library: library,
    remote: remote,
    log: log ?? CameraLog(),
    stateFile: File(p.join(library.directory.path, 'sync.json')),
    clock: () => now,
    photos: photos,
  );

  Recipe recipe(String id, String name) => Recipe(
    id: id,
    name: name,
    values: const {'highlight': 1},
    updatedAt: DateTime.utc(2000),
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('sync_service_test');
    now = DateTime.utc(2026, 10, 17, 9);
    remote = FakeRemote();
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('원격 행을 합치고, 원격에 없는 기기 행을 올리고, 시각을 남긴다', () async {
    final library = newLibrary('a');
    await library.load();
    await library.saveRecipe(recipe(idA, 'Local'));
    remote.recipeRows[idB] = recipe(idB, 'Remote').toJson();
    final service = newService(library);

    expect(await service.sync(), isTrue);

    expect(library.recipes.map((r) => r.name), ['Local', 'Remote']);
    expect(remote.uploadedRecipes.single, [idA]);
    expect(service.lastSyncAt, now);
    final reloaded = newService(library);
    await reloaded.loadState();
    expect(reloaded.lastSyncAt, now);
  });

  test('오프라인에서 먼저 고친 기기가 늦게 동기화해도 다른 기기의 더 최근 수정을 덮어쓰지 않는다', () async {
    final deviceA = newLibrary('a');
    final deviceB = newLibrary('b');
    await deviceA.load();
    await deviceB.load();
    await deviceA.saveRecipe(recipe(idA, 'Original'));
    await newService(deviceA).sync();
    await newService(deviceB).sync();

    now = DateTime.utc(2026, 10, 17, 10);
    await deviceA.saveRecipe(
      deviceA.recipes.single.copyWith(name: 'A 10시', updatedAt: now),
    );
    now = DateTime.utc(2026, 10, 17, 11);
    await deviceB.saveRecipe(
      deviceB.recipes.single.copyWith(name: 'B 11시', updatedAt: now),
    );
    await newService(deviceB).sync();

    now = DateTime.utc(2026, 10, 17, 12);
    await newService(deviceA).sync();

    expect(deviceA.recipes.single.name, 'B 11시');
    expect(Recipe.fromJson(remote.recipeRows[idA]).name, 'B 11시');
  });

  test('다른 기기 시계가 늦어도, 마지막 동기화 시각보다 이른 원격 행을 받는다', () async {
    final library = newLibrary('a');
    await library.load();
    final service = newService(library);
    await service.sync();

    remote.recipeRows[idB] = recipe(idB, '시계가 늦은 기기').toJson();
    now = now.add(const Duration(hours: 1));
    await service.sync();

    expect(library.recipes.single.name, '시계가 늦은 기기');
  });

  test('형식이 맞지 않는 원격 행은 건너뛰고, 그 id 의 기기 행으로 덮어쓰지도 않는다', () async {
    final library = newLibrary('a');
    await library.load();
    await library.saveRecipe(recipe(idA, 'Local'));
    final broken = {'id': idA, 'name': 'newer app', 'values': 'unknown'};
    remote.recipeRows[idA] = broken;
    remote.recipeRows[idB] = recipe(idB, 'Remote').toJson();
    remote.loadoutRows['x'] = {'slots': []};
    final log = CameraLog();

    expect(await newService(library, log: log).sync(), isTrue);

    expect(library.recipes.map((r) => r.name), ['Local', 'Remote']);
    expect(remote.recipeRows[idA], broken);
    expect(log.entries.last.$2, contains('건너뜀 2'));
  });

  test('원격에 닿지 못하면 기기 데이터와 동기화 시각은 그대로 두고 로그에 남긴다', () async {
    final library = newLibrary('a');
    await library.load();
    await library.saveRecipe(recipe(idA, 'Local'));
    remote.failure = const SocketException('offline');
    final log = CameraLog();
    final service = newService(library, log: log);

    expect(await service.sync(), isFalse);

    expect(library.recipes.single.name, 'Local');
    expect(service.lastSyncAt, isNull);
    expect(log.entries.last.$2, startsWith('동기화 실패'));
  });

  group('사진 동기화', () {
    PhotoSync photoSync(RemotePhotosForTest remote, CameraLog log) => PhotoSync(
      photos: PhotoIndexStore(Directory(p.join(root.path, 'photos'))),
      logs: PlaceLogStore(Directory(p.join(root.path, 'photos'))),
      remote: remote,
      log: log,
    );

    test('보관함 다음에 사진과 기록도 맞춘다', () async {
      final library = newLibrary('a');
      await library.load();
      final log = CameraLog();

      expect(
        await newService(
          library,
          log: log,
          photos: photoSync(RemotePhotosForTest(), log),
        ).sync(),
        isTrue,
      );

      expect(log.entries.map((e) => e.$2), [
        startsWith('동기화:'),
        startsWith('사진 동기화:'),
      ]);
    });

    test('사진 동기화가 실패해도 보관함 동기화는 성공으로 남는다', () async {
      final library = newLibrary('a');
      await library.load();
      final log = CameraLog();
      final service = newService(
        library,
        log: log,
        photos: photoSync(
          RemotePhotosForTest()..failure = Exception('photos 테이블 없음'),
          log,
        ),
      );

      expect(await service.sync(), isTrue);

      expect(service.lastSyncAt, now);
      expect(log.entries.last.$2, startsWith('사진 동기화 실패'));
    });
  });
}

class RemotePhotosForTest extends FakeRemotePhotos {
  Exception? failure;

  @override
  Future<List<Object?>> fetchPhotos() async {
    if (failure case final error?) throw error;
    return super.fetchPhotos();
  }
}
