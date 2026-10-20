import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/library/loadout.dart';
import 'package:recipe_slot_manager/photo/locator.dart';
import 'package:recipe_slot_manager/photo/photo_index_store.dart';
import 'package:recipe_slot_manager/photo/place_log_store.dart';
import 'package:recipe_slot_manager/photo/place_logger.dart';
import 'package:recipe_slot_manager/photo/place_resolver.dart';
import 'package:recipe_slot_manager/photo/place_store.dart';

import '../support/fake_geocoder.dart';
import '../support/fake_locator.dart';

void main() {
  late Directory root;
  late PlaceLogStore store;
  late PlaceStore places;
  late FakeGeocoder geocoder;
  late CameraLog log;
  late PlaceResolver resolver;
  final now = DateTime.utc(2026, 10, 20, 5, 3);
  final loadout = Loadout(
    id: 'loadout-1',
    name: '도쿄 밤',
    slots: List.filled(7, null),
    updatedAt: now,
  );
  const slots = ['Eterna 밤', null, null, null, null, null, null];

  PlaceLogger logger(Locator? locator) => PlaceLogger(
    store: store,
    locator: locator,
    resolver: resolver,
    log: log,
    clock: () => now,
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('place_logger_test');
    store = PlaceLogStore(Directory('${root.path}/photos'));
    places = PlaceStore(Directory('${root.path}/photos'));
    geocoder = FakeGeocoder();
    log = CameraLog();
    resolver = PlaceResolver(
      photos: PhotoIndexStore(Directory('${root.path}/photos')),
      places: places,
      geocoder: geocoder,
      log: log,
      logs: store,
      wait: (_) async {},
    );
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('위치를 받으면 좌표·오차와 세트를 기록하고 장소 이름을 묻는다', () async {
    final locator = FakeLocator(
      fix: (point: (latitude: 35.6587, longitude: 139.7005), accuracy: 12.0),
    );

    await logger(locator).record(loadout: loadout, slots: slots, model: 'X-T5');

    final saved = store.logs.single;
    expect(saved.location, (latitude: 35.6587, longitude: 139.7005));
    expect(saved.accuracy, 12.0);
    expect(saved.loadoutId, 'loadout-1');
    expect(saved.loadoutName, '도쿄 밤');
    expect(saved.slots, slots);
    expect(saved.model, 'X-T5');
    expect(saved.loggedAt, now);
    expect(saved.id, hasLength(32));
    expect(geocoder.requests.single, (latitude: 35.6587, longitude: 139.7005));
    expect(places.contains('35.6587,139.7005'), isTrue);
    expect(
      log.entries.map((e) => e.$2),
      contains('저장 기록: 도쿄 밤 · 35.6587, 139.7005 (약 12 m)'),
    );
  });

  test('위치를 받지 못해도 이유와 함께 위치 없이 기록한다', () async {
    final locator = FakeLocator(
      failure: const LocateException('denied', '위치 권한이 없습니다'),
    );

    await logger(locator).record(loadout: loadout, slots: slots);

    final saved = store.logs.single;
    expect(saved.location, isNull);
    expect(saved.missingReason, '위치 권한이 없습니다');
    expect(geocoder.requests, isEmpty);
    expect(log.entries.last.$2, '저장 기록: 도쿄 밤 · 위치 없음 (위치 권한이 없습니다)');
  });

  test('위치를 받을 수 없는 기기(locator 없음)도 기록한다', () async {
    await logger(null).record(loadout: loadout, slots: slots);

    expect(store.logs.single.missingReason, '이 기기에서는 위치를 기록하지 않습니다');
  });

  test('기록 파일을 쓰지 못하면 로그만 남기고 던지지 않는다', () async {
    File('${root.path}/photos').createSync(recursive: true);

    await logger(null).record(loadout: loadout, slots: slots);

    expect(log.entries.last.$2, startsWith('저장 기록 실패:'));
  });

  test('prepare 는 위치 권한을 요청한다. locator 가 없으면 아무것도 하지 않는다', () async {
    final locator = FakeLocator(granted: false);

    await logger(locator).prepare();
    await logger(null).prepare();

    expect(locator.accessRequests, 1);
  });
}
