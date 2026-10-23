import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/photo/photo_index_store.dart';
import 'package:recipe_slot_manager/photo/photo_info.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/photo/place_log.dart';
import 'package:recipe_slot_manager/photo/place_log_store.dart';
import 'package:recipe_slot_manager/sync/photo_sync.dart';
import 'package:recipe_slot_manager/sync/remote_photos.dart';

/// 키·id 별 body 를 들고 있는 가짜 원격. 올린 행은 그대로 저장한다.
class FakeRemotePhotos implements RemotePhotos {
  final photoRows = <String, Object?>{};
  final logRows = <String, Object?>{};
  final uploadedPhotos = <String>[];
  final uploadedLogs = <String>[];

  @override
  Future<List<Object?>> fetchPhotos() async => photoRows.values.toList();

  @override
  Future<void> upsertPhotos(List<RemotePhoto> photos) async {
    for (final photo in photos) {
      uploadedPhotos.add(photo.key);
      photoRows[photo.key] = photo.toJson();
    }
  }

  @override
  Future<List<Object?>> fetchLogs() async => logRows.values.toList();

  @override
  Future<void> upsertLogs(List<PlaceLog> logs) async {
    for (final log in logs) {
      uploadedLogs.add(log.id);
      logRows[log.id] = log.toJson();
    }
  }
}

void main() {
  late Directory root;
  late PhotoIndexStore photos;
  late PlaceLogStore logs;
  late FakeRemotePhotos remote;
  late CameraLog log;
  late PhotoSync sync;
  final shot = DateTime.utc(2026, 10, 11, 15, 26, 10);
  const tokyo = (latitude: 35.6587, longitude: 139.7005);

  IndexedPhoto local(String name, {GeoPoint? location, DateTime? shotAt}) =>
      IndexedPhoto(
        sourceId: 's1',
        file: (id: '/m/$name', name: name, size: 100, modifiedMs: 1),
        info: PhotoInfo(
          shotAt: shotAt ?? shot,
          utcOffset: const Duration(hours: 9),
          location: location,
          model: 'X-T5',
          recipe: const {'filmSimulation': 16},
        ),
      );

  String keyOf(String name) =>
      '${name.toLowerCase()}|${shot.toIso8601String()}';

  PlaceLog placeLog(String id) => PlaceLog(
    id: id * 32,
    loggedAt: DateTime.utc(2026, 10, 20),
    utcOffset: Duration.zero,
    loadoutId: 'l1',
    loadoutName: '세트',
    slots: List.filled(7, null),
  );

  Future<void> putLocal(List<IndexedPhoto> list) async {
    await photos.saveSource(
      const PhotoSource(
        id: 's1',
        kind: PhotoSourceKind.folder,
        name: 'X-T5',
        location: '/m',
      ),
    );
    await photos.replacePhotos('s1', list);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('photo_sync_test');
    photos = PhotoIndexStore(Directory('${root.path}/photos'));
    logs = PlaceLogStore(Directory('${root.path}/photos'));
    remote = FakeRemotePhotos();
    log = CameraLog();
    sync = PhotoSync(photos: photos, logs: logs, remote: remote, log: log);
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('이 기기 사진을 올리고, 다른 기기 사진을 받아 함께 보인다', () async {
    await putLocal([local('DSCF0001.JPG')]);
    remote.photoRows[keyOf('DSCF0002.JPG')] = RemotePhoto(
      key: keyOf('DSCF0002.JPG'),
      name: 'DSCF0002.JPG',
      info: PhotoInfo(shotAt: shot, location: tokyo),
    ).toJson();

    await sync.sync();

    expect(remote.uploadedPhotos, [keyOf('DSCF0001.JPG')]);
    final read = RemotePhoto.fromJson(remote.photoRows[keyOf('DSCF0001.JPG')]);
    expect(read.info.model, 'X-T5');
    expect(read.info.recipe, {'filmSimulation': 16});
    expect(photos.photos.map((p) => p.file.name).toSet(), {
      'DSCF0001.JPG',
      'DSCF0002.JPG',
    });
    expect(photos.otherDevicePhotos.single.info?.location, tokyo);
  });

  test('원격에 같은 사진이 있으면 다시 올리지 않고, 위치가 새로 생겼을 때만 올린다', () async {
    await putLocal([local('DSCF0001.JPG')]);
    await sync.sync();
    remote.uploadedPhotos.clear();

    await sync.sync();
    expect(remote.uploadedPhotos, isEmpty);

    await photos.replacePhotos('s1', [local('DSCF0001.JPG', location: tokyo)]);
    await sync.sync();
    expect(remote.uploadedPhotos, [keyOf('DSCF0001.JPG')]);
  });

  test('이 기기 사본에 위치가 없으면 원격의 위치를 지우지 않는다', () async {
    remote.photoRows[keyOf('DSCF0001.JPG')] = RemotePhoto(
      key: keyOf('DSCF0001.JPG'),
      name: 'DSCF0001.JPG',
      info: PhotoInfo(shotAt: shot, location: tokyo),
    ).toJson();
    await putLocal([local('DSCF0001.JPG')]);

    await sync.sync();

    expect(remote.uploadedPhotos, isEmpty);
    expect(photos.photos.single.info?.location, tokyo);
  });

  test('촬영 시각이 없거나 읽지 못한 사진은 올리지 않는다', () async {
    await putLocal([
      IndexedPhoto(
        sourceId: 's1',
        file: (id: 'a', name: 'a.jpg', size: 1, modifiedMs: 1),
        info: const PhotoInfo(),
      ),
      const IndexedPhoto(
        sourceId: 's1',
        file: (id: 'b', name: 'b.jpg', size: 1, modifiedMs: 1),
        error: '깨짐',
      ),
    ]);

    await sync.sync();

    expect(remote.uploadedPhotos, isEmpty);
  });

  test('형식이 틀린 원격 행은 건너뛰고 로그에 센다', () async {
    remote.photoRows['x'] = {'key': 'x'};

    await sync.sync();

    expect(photos.otherDevicePhotos, isEmpty);
    expect(log.entries.last.$2, contains('건너뜀 1'));
  });

  test('기록: 없는 id 만 받고, 원격에 없는 이 기기 기록만 올린다', () async {
    await logs.add(placeLog('a'));
    await logs.add(placeLog('b'));
    remote.logRows['b' * 32] = placeLog('b').toJson();
    remote.logRows['c' * 32] = placeLog('c').toJson();

    await sync.sync();

    expect(remote.uploadedLogs, ['a' * 32]);
    expect(logs.logs.map((l) => l.id).toSet(), {'a' * 32, 'b' * 32, 'c' * 32});
    expect(log.entries.last.$2, '사진 동기화: 사진 받음 0, 올림 0, 기록 받음 1, 올림 1, 건너뜀 0');
  });
}
