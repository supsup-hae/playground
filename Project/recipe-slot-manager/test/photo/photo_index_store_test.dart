import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/photo/photo_index_store.dart';
import 'package:recipe_slot_manager/photo/photo_info.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';

void main() {
  late Directory root;
  final now = DateTime.utc(2026, 10, 20, 9);

  PhotoIndexStore newStore() => PhotoIndexStore(root, clock: () => now);

  const folder = PhotoSource(
    id: 's1',
    kind: PhotoSourceKind.folder,
    name: 'X-T5',
    location: '/Users/me/Pictures/X-T5',
    bookmark: 'Ym9va21hcms=',
  );
  const album = PhotoSource(
    id: 's2',
    kind: PhotoSourceKind.mediaFolder,
    name: 'FUJIFILM XApp',
    location: 'Pictures/FUJIFILM XApp/',
  );

  IndexedPhoto photo(
    String sourceId,
    String id, {
    int? filmSimulation,
    GeoPoint? location,
    String? error,
  }) => IndexedPhoto(
    sourceId: sourceId,
    file: (id: id, name: id, size: 100, modifiedMs: 1),
    info: error == null
        ? PhotoInfo(
            location: location,
            recipe: {'filmSimulation': ?filmSimulation?.toDouble()},
          )
        : null,
    error: error,
  );

  setUp(() => root = Directory.systemTemp.createTempSync('photo_index_test'));
  tearDown(() => root.deleteSync(recursive: true));

  test('출처와 항목을 저장했다가 다시 읽는다', () async {
    final store = newStore();
    await store.saveSource(folder);
    await store.saveSource(album);
    await store.replacePhotos('s1', [
      photo('s1', 'a.jpg', filmSimulation: 0x10),
      IndexedPhoto(
        sourceId: 's1',
        file: (id: 'b.jpg', name: 'b.jpg', size: 7, modifiedMs: 2),
        info: const PhotoInfo(),
        locationRedacted: true,
      ),
    ]);
    await store.replacePhotos('s2', [photo('s2', 'c', error: 'JPEG 아님')]);

    final read = newStore();
    await read.load();

    expect(read.sources.map((s) => s.toJson()), [
      folder.copyWith(indexedAt: now).toJson(),
      album.copyWith(indexedAt: now).toJson(),
    ]);
    expect(
      read.photos.map((p) => p.toJson()),
      store.photos.map((p) => p.toJson()),
    );
    expect(read.photosOf('s1').last.locationRedacted, isTrue);
    expect(read.photosOf('s2').single.error, 'JPEG 아님');
  });

  test('파일이 없으면 빈 색인', () async {
    final store = newStore();
    await store.load();

    expect(store.sources, isEmpty);
    expect(store.photos, isEmpty);
  });

  test('깨진 파일은 옮기고 빈 색인으로 시작한다', () async {
    final file = File(p.join(root.path, 'photos.json'))
      ..writeAsStringSync('{"sources": 1}');
    final store = newStore();

    await store.load();

    expect(store.sources, isEmpty);
    expect(file.existsSync(), isFalse);
    expect(store.loadErrors.single, startsWith('photos.json 읽기 실패'));
  });

  test('출처를 빼면 그 출처의 항목만 지운다', () async {
    final store = newStore();
    await store.saveSource(folder);
    await store.saveSource(album);
    await store.replacePhotos('s1', [photo('s1', 'a.jpg')]);
    await store.replacePhotos('s2', [photo('s2', 'c')]);

    await store.removeSource('s1');

    expect(store.sources.map((s) => s.id), ['s2']);
    expect(store.photos.map((p) => p.sourceId), ['s2']);
  });

  test('요약: 전체, 위치 있음, 실패, 필름 시뮬레이션별 수(많은 순)', () async {
    final store = newStore();
    await store.saveSource(folder);
    await store.replacePhotos('s1', [
      photo('s1', '1', filmSimulation: 0x10),
      photo(
        's1',
        '2',
        filmSimulation: 0x10,
        location: (latitude: 35, longitude: 139),
      ),
      photo('s1', '3', filmSimulation: 0x11),
      photo('s1', '4'),
      photo('s1', '5', error: '깨짐'),
    ]);

    final summary = store.summary;

    expect(summary.total, 5);
    expect(summary.withLocation, 1);
    expect(summary.failed, 1);
    expect(summary.byFilmSimulation.entries.map((e) => (e.key, e.value)), [
      (0x10, 2),
      (0x11, 1),
    ]);
  });

  test('항목 JSON 형식이 맞지 않으면 FormatException', () {
    expect(
      () => IndexedPhoto.fromJson({'sourceId': 's1'}),
      throwsFormatException,
    );
    expect(() => PhotoSource.fromJson({'id': 's1'}), throwsFormatException);
    expect(
      () => PhotoSource.fromJson({...folder.toJson(), 'bookmark': 1}),
      throwsFormatException,
    );
    expect(
      () =>
          IndexedPhoto.fromJson({...photo('s1', 'a').toJson(), 'error': false}),
      throwsFormatException,
    );
  });
}
