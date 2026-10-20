import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/photo/geocoder.dart';
import 'package:recipe_slot_manager/photo/photo_index_store.dart';
import 'package:recipe_slot_manager/photo/photo_info.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/photo/place.dart';
import 'package:recipe_slot_manager/photo/place_log.dart';
import 'package:recipe_slot_manager/photo/place_log_store.dart';
import 'package:recipe_slot_manager/photo/place_resolver.dart';
import 'package:recipe_slot_manager/photo/place_store.dart';

import '../support/fake_geocoder.dart';

void main() {
  late Directory root;
  late PhotoIndexStore photos;
  late PlaceStore places;
  late PlaceLogStore logs;
  late FakeGeocoder geocoder;
  late CameraLog log;
  late List<Duration> waits;
  late PlaceResolver resolver;

  Future<void> putPhotos(List<GeoPoint?> locations) async {
    await photos.saveSource(
      const PhotoSource(
        id: 's1',
        kind: PhotoSourceKind.folder,
        name: 'X-T5',
        location: '/photos',
      ),
    );
    await photos.replacePhotos('s1', [
      for (var i = 0; i < locations.length; i++)
        IndexedPhoto(
          sourceId: 's1',
          file: (id: '$i.jpg', name: '$i.jpg', size: 1, modifiedMs: 1),
          info: PhotoInfo(location: locations[i]),
        ),
    ]);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('place_resolver_test');
    photos = PhotoIndexStore(Directory('${root.path}/photos'));
    places = PlaceStore(Directory('${root.path}/places'));
    logs = PlaceLogStore(Directory('${root.path}/places'));
    geocoder = FakeGeocoder();
    log = CameraLog();
    waits = [];
    resolver = PlaceResolver(
      photos: photos,
      places: places,
      geocoder: geocoder,
      log: log,
      logs: logs,
      wait: (d) async => waits.add(d),
    );
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('이름이 없는 좌표만, 같은 키는 한 번만, 요청 사이 1초씩 묻는다', () async {
    await putPhotos([
      (latitude: 35.65871, longitude: 139.7),
      (latitude: 35.65872, longitude: 139.7),
      (latitude: 34.0, longitude: 135.0),
      null,
    ]);
    await places.save('34.0000,135.0000', const Place(country: '일본'));
    final progress = <(int, int)>[];

    final result = await resolver.resolveMissing(
      onProgress: (done, total) => progress.add((done, total)),
    );

    expect(geocoder.requests, hasLength(1));
    expect(waits, isEmpty);
    expect((result.resolved, result.remaining), (1, 0));
    expect(places.place('35.6587,139.7000')?.country, '나라 35.65871');
    expect(progress, [(0, 1), (1, 1)]);
    expect(log.entries.last.$2, '장소 이름: 받음 1');
  });

  test('요청 사이에는 1초를 기다린다', () async {
    await putPhotos([
      (latitude: 1.0, longitude: 1.0),
      (latitude: 2.0, longitude: 2.0),
      (latitude: 3.0, longitude: 3.0),
    ]);

    await resolver.resolveMissing();

    expect(waits, [const Duration(seconds: 1), const Duration(seconds: 1)]);
  });

  test('결과가 없는 곳은 빈 장소로 저장해 다시 묻지 않는다', () async {
    await putPhotos([(latitude: 0.0, longitude: 10.0)]);

    await resolver.resolveMissing();
    await resolver.resolveMissing();

    expect(geocoder.requests, hasLength(1));
    expect(places.place('0.0000,10.0000')?.isEmpty, isTrue);
  });

  test('네트워크 오류면 멈추고 로그를 남기며, 다음에 남은 것부터 묻는다', () async {
    await putPhotos([
      (latitude: 1.0, longitude: 1.0),
      (latitude: 2.0, longitude: 2.0),
      (latitude: 3.0, longitude: 3.0),
    ]);
    geocoder.failAt = 1;

    final first = await resolver.resolveMissing();
    geocoder.failAt = null;
    geocoder.requests.clear();
    final second = await resolver.resolveMissing();

    expect((first.resolved, first.remaining), (1, 2));
    expect(log.entries.map((e) => e.$2), contains('장소 이름: 받음 1, 남음 2 (연결 없음)'));
    expect(geocoder.requests, hasLength(2));
    expect((second.resolved, second.remaining), (2, 0));
  });

  test('네트워크·호출 제한·사용 불가가 아닌 오류는 그 좌표만 건너뛰고 계속 묻는다', () async {
    await putPhotos([
      (latitude: 1.0, longitude: 1.0),
      (latitude: 2.0, longitude: 2.0),
    ]);
    geocoder
      ..failAt = 0
      ..failure = const GeocodeException('geocode', '알 수 없는 오류');

    final result = await resolver.resolveMissing();

    expect(geocoder.requests, hasLength(2));
    expect((result.resolved, result.remaining), (1, 1));
    expect(places.contains('1.0000,1.0000'), isFalse);
    expect(places.contains('2.0000,2.0000'), isTrue);
    expect(log.entries.last.$2, '장소 이름: 받음 1, 실패 1 (알 수 없는 오류)');
  });

  test('물을 것이 없으면 로그를 남기지 않는다', () async {
    await putPhotos([null]);

    final result = await resolver.resolveMissing();

    expect((result.resolved, result.remaining), (0, 0));
    expect(log.entries, isEmpty);
  });

  test('세트 저장 기록의 좌표도 묻는다', () async {
    await logs.add(
      PlaceLog(
        id: 'log-1',
        loggedAt: DateTime.utc(2026, 10, 20),
        utcOffset: Duration.zero,
        location: (latitude: 5.0, longitude: 5.0),
        loadoutId: 'loadout-1',
        loadoutName: '세트',
        slots: List.filled(7, null),
      ),
    );

    await resolver.resolveMissing();

    expect(geocoder.requests.single, (latitude: 5.0, longitude: 5.0));
  });

  test('겹쳐 부르면 앞 호출이 끝난 뒤 돌아 같은 좌표를 두 번 묻지 않는다', () async {
    await putPhotos([
      (latitude: 1.0, longitude: 1.0),
      (latitude: 2.0, longitude: 2.0),
    ]);

    await Future.wait([resolver.resolveMissing(), resolver.resolveMissing()]);

    expect(geocoder.requests, hasLength(2));
  });
}
