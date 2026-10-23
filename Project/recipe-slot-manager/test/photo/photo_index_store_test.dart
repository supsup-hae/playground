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

  group('같은 사진(파일 이름 + 촬영 시각)은 한 번만', () {
    final shot = DateTime.utc(2026, 10, 11, 15, 26, 10);

    IndexedPhoto copy(
      String sourceId,
      String id,
      String name, {
      DateTime? shotAt,
      GeoPoint? location,
    }) => IndexedPhoto(
      sourceId: sourceId,
      file: (id: id, name: name, size: 100, modifiedMs: 1),
      info: PhotoInfo(shotAt: shotAt, location: location),
    );

    Future<PhotoIndexStore> storeWith(
      List<IndexedPhoto> mac,
      List<IndexedPhoto> phone,
    ) async {
      final store = newStore();
      await store.saveSource(folder);
      await store.saveSource(album);
      await store.replacePhotos('s1', mac);
      await store.replacePhotos('s2', phone);
      return store;
    }

    test('Mac 과 휴대폰에 같은 사진이 있으면 하나로 보이고, 위치가 있는 쪽을 쓴다', () async {
      final store = await storeWith(
        [copy('s1', '/m/DSCF1422.JPG', 'DSCF1422.JPG', shotAt: shot)],
        [
          copy(
            's2',
            'content://1',
            'dscf1422.jpg',
            shotAt: shot,
            location: (latitude: 35.6, longitude: 139.7),
          ),
        ],
      );

      expect(store.photos.single.sourceId, 's2');
      expect(store.summary.total, 1);
      expect(store.photosOf('s1'), hasLength(1), reason: '출처별 색인은 그대로');
    });

    test('이름이 같아도 촬영 시각이 다르면(번호가 돌아 다시 쓰인 경우) 다른 사진', () async {
      final store = await storeWith(
        [copy('s1', 'a', 'DSCF0001.JPG', shotAt: shot)],
        [
          copy(
            's2',
            'b',
            'DSCF0001.JPG',
            shotAt: shot.add(const Duration(days: 400)),
          ),
        ],
      );

      expect(store.photos, hasLength(2));
    });

    test('저장했다가 다시 읽어도 출처별 항목은 둘 다 남는다', () async {
      await storeWith(
        [copy('s1', 'a', 'DSCF1422.JPG', shotAt: shot)],
        [copy('s2', 'b', 'DSCF1422.JPG', shotAt: shot)],
      );

      final read = newStore();
      await read.load();

      expect(read.photosOf('s1'), hasLength(1));
      expect(read.photosOf('s2'), hasLength(1));
      expect(read.photos, hasLength(1));
    });

    test('촬영 시각이 없으면 이름이 같아도 합치지 않는다', () async {
      final store = await storeWith(
        [copy('s1', 'a', 'IMG_0001.JPG')],
        [copy('s2', 'b', 'IMG_0001.JPG')],
      );

      expect(store.photos, hasLength(2));
    });

    test('읽지 못한 사진은 합치지 않는다', () async {
      final store = await storeWith(
        [photo('s1', 'DSCF0002.JPG', error: '깨짐')],
        [photo('s2', 'DSCF0002.JPG', error: '깨짐')],
      );

      expect(store.photos, hasLength(2));
    });
  });

  group('다른 기기 사진', () {
    final shot = DateTime.utc(2026, 10, 11, 15, 26, 10);
    const tokyo = (latitude: 35.6, longitude: 139.7);

    IndexedPhoto local(String name, {GeoPoint? location}) => IndexedPhoto(
      sourceId: 's1',
      file: (id: '/m/$name', name: name, size: 100, modifiedMs: 1),
      info: PhotoInfo(shotAt: shot, location: location),
    );

    IndexedPhoto remote(String name, {GeoPoint? location}) => IndexedPhoto(
      sourceId: otherDeviceSourceId,
      file: (id: name, name: name, size: 0, modifiedMs: 0),
      info: PhotoInfo(shotAt: shot, location: location),
    );

    test('다른 기기에만 있는 사진도 보이고, 저장했다가 다시 읽어도 남는다', () async {
      final store = newStore();
      await store.replaceOtherDevice([remote('DSCF0001.JPG')]);

      final read = newStore();
      await read.load();

      expect(read.photos.single.fromOtherDevice, isTrue);
      expect(read.localPhotos, isEmpty);
    });

    test('이 기기에도 있으면 이 기기 것을 쓰고, 위치가 없으면 다른 기기의 위치를 빌린다', () async {
      final store = newStore();
      await store.saveSource(folder);
      await store.replacePhotos('s1', [local('DSCF0001.JPG')]);
      await store.replaceOtherDevice([remote('dscf0001.jpg', location: tokyo)]);

      final shown = store.photos.single;
      expect(shown.sourceId, 's1');
      expect(shown.info?.location, tokyo);
      expect(store.localPhotos.single.info?.location, isNull);
    });

    test('요약은 이 기기 출처의 사진만 센다', () async {
      final store = newStore();
      await store.replaceOtherDevice([remote('DSCF0001.JPG')]);

      expect(store.summary.total, 0);
    });

    test('같은 사진 키: 이름(소문자)과 촬영 시각, 시각이 없으면 null', () {
      expect(
        PhotoIndexStore.photoKey(local('DSCF0001.JPG')),
        'dscf0001.jpg|${shot.toIso8601String()}',
      );
      expect(PhotoIndexStore.photoKey(photo('s1', 'a.jpg')), isNull);
    });
  });
}
