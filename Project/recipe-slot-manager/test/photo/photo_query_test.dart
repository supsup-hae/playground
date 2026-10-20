import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/photo/photo_info.dart';
import 'package:recipe_slot_manager/photo/photo_query.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/photo/place.dart';
import 'package:recipe_slot_manager/photo/place_log.dart';
import 'package:recipe_slot_manager/photo/place_store.dart';

const eterna = 0x10;
const classicNeg = 0x11;

void main() {
  late Directory root;
  late PlaceStore places;

  const shibuya = (latitude: 35.6587, longitude: 139.7005);
  const namba = (latitude: 34.6662, longitude: 135.5012);
  const seoul = (latitude: 37.5665, longitude: 126.978);

  IndexedPhoto photo(
    String name, {
    DateTime? shotAt,
    GeoPoint? location,
    int? film,
    String? error,
  }) => IndexedPhoto(
    sourceId: 's1',
    file: (id: name, name: name, size: 1, modifiedMs: 1),
    info: error == null
        ? PhotoInfo(
            shotAt: shotAt,
            location: location,
            recipe: {'filmSimulation': ?film?.toDouble()},
          )
        : null,
    error: error,
  );

  late List<IndexedPhoto> photos;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('photo_query_test');
    places = PlaceStore(root);
    await places.save(
      placeKey(shibuya),
      const Place(
        country: '일본',
        admin: '도쿄도',
        locality: '시부야구',
        subLocality: '진난',
        thoroughfare: '공원 거리',
      ),
    );
    await places.save(
      placeKey(namba),
      const Place(country: '일본', admin: '오사카부', locality: '오사카시'),
    );
    await places.save(
      placeKey(seoul),
      const Place(country: '대한민국', admin: '서울특별시', locality: '중구'),
    );
    photos = [
      photo(
        'a.jpg',
        shotAt: DateTime.utc(2025, 10, 12, 15),
        location: shibuya,
        film: eterna,
      ),
      photo(
        'b.jpg',
        shotAt: DateTime.utc(2025, 10, 13, 9),
        location: namba,
        film: classicNeg,
      ),
      photo(
        'c.jpg',
        shotAt: DateTime.utc(2026, 3, 1),
        location: seoul,
        film: eterna,
      ),
      photo('d.jpg', shotAt: DateTime.utc(2025, 1, 2), film: eterna),
      photo('e.jpg'),
      photo('broken.jpg', error: 'JPEG 파일이 아닙니다'),
    ];
  });
  tearDown(() => root.deleteSync(recursive: true));

  List<String> names(PhotoFilter filter) => [
    for (final entry in queryPhotos(photos, places, filter))
      entry.photo.file.name,
  ];

  test('조건이 없으면 읽은 사진 전부를 최신순으로, 시각이 없는 사진은 맨 뒤에', () {
    expect(names(const PhotoFilter()), [
      'c.jpg',
      'b.jpg',
      'a.jpg',
      'd.jpg',
      'e.jpg',
    ]);
  });

  test('연도', () {
    expect(names(const PhotoFilter(year: 2025)), ['b.jpg', 'a.jpg', 'd.jpg']);
  });

  test('나라 → 광역 → 도시', () {
    expect(names(const PhotoFilter(country: '일본')), ['b.jpg', 'a.jpg']);
    expect(names(const PhotoFilter(country: '일본', admin: '도쿄도')), ['a.jpg']);
    expect(
      names(const PhotoFilter(country: '일본', admin: '오사카부', locality: '오사카시')),
      ['b.jpg'],
    );
  });

  test('필름 시뮬레이션은 여러 개를 고를 수 있다', () {
    expect(names(const PhotoFilter(films: {eterna})), [
      'c.jpg',
      'a.jpg',
      'd.jpg',
    ]);
    expect(names(const PhotoFilter(films: {eterna, classicNeg})), [
      'c.jpg',
      'b.jpg',
      'a.jpg',
      'd.jpg',
    ]);
  });

  test('위치 없음만', () {
    expect(names(const PhotoFilter(noLocationOnly: true)), ['d.jpg', 'e.jpg']);
  });

  test('조건을 함께 쓴다: 2025년·일본·Eterna', () {
    expect(
      names(const PhotoFilter(year: 2025, country: '일본', films: {eterna})),
      ['a.jpg'],
    );
  });

  group('검색어', () {
    test('낱말마다 장소 이름·파일 이름·시뮬레이션 이름 중 하나에 있으면 맞다', () {
      expect(names(const PhotoFilter(text: '시부야 eterna')), ['a.jpg']);
      expect(names(const PhotoFilter(text: '공원')), ['a.jpg']);
      expect(names(const PhotoFilter(text: 'B.JPG')), ['b.jpg']);
      expect(names(const PhotoFilter(text: '일본 classic')), ['b.jpg']);
    });

    test('하나라도 맞지 않는 낱말이 있으면 뺀다', () {
      expect(names(const PhotoFilter(text: '시부야 classic')), isEmpty);
    });

    test('공백뿐인 검색어는 조건이 아니다', () {
      expect(names(const PhotoFilter(text: '  ')), hasLength(5));
    });
  });

  test('항목은 장소를 함께 준다', () {
    final entry = queryPhotos(
      photos,
      places,
      const PhotoFilter(text: 'a.jpg'),
    ).single;

    expect(entry.place?.locality, '시부야구');
  });

  test('2,000장에서 2025년·일본·Eterna 를 거르고 선택지를 만드는 데 1초가 걸리지 않는다', () {
    final many = [
      for (var i = 0; i < 2000; i++)
        photo(
          '$i.jpg',
          shotAt: DateTime.utc(2024 + i % 3, 1 + i % 12, 1 + i % 28),
          location: [shibuya, namba, seoul, null][i % 4],
          film: i.isEven ? eterna : classicNeg,
        ),
    ];
    final watch = Stopwatch()..start();

    final found = queryPhotos(
      many,
      places,
      const PhotoFilter(year: 2025, country: '일본', films: {eterna}),
    );
    photoFacets(many, places, const PhotoFilter(country: '일본'));

    expect(found, isNotEmpty);
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
  });

  group('선택지', () {
    test('연도는 최신순, 나라는 사진 수가 많은 순', () {
      final facets = photoFacets(photos, places, const PhotoFilter());

      expect(facets.years, [2026, 2025]);
      expect(facets.countries, ['일본', '대한민국']);
      expect(facets.admins, isEmpty);
      expect(facets.localities, isEmpty);
    });

    test('나라를 고르면 그 나라의 광역, 광역을 고르면 그 광역의 도시', () {
      final byCountry = photoFacets(
        photos,
        places,
        const PhotoFilter(country: '일본'),
      );
      final byAdmin = photoFacets(
        photos,
        places,
        const PhotoFilter(country: '일본', admin: '도쿄도'),
      );

      expect(byCountry.admins.toSet(), {'도쿄도', '오사카부'});
      expect(byAdmin.localities, ['시부야구']);
    });

    test('필름 시뮬레이션은 사진 수와 함께, 많은 순', () {
      final facets = photoFacets(photos, places, const PhotoFilter());

      expect(facets.films.entries.map((e) => (e.key, e.value)), [
        (eterna, 3),
        (classicNeg, 1),
      ]);
    });
  });

  group('세트 저장 기록', () {
    PlaceLog log(
      String id, {
      required DateTime at,
      Duration offset = Duration.zero,
      GeoPoint? location,
      String loadout = '세트',
      String? slot,
    }) => PlaceLog(
      id: id,
      loggedAt: at,
      utcOffset: offset,
      location: location,
      loadoutId: 'loadout-$id',
      loadoutName: loadout,
      slots: [slot, null, null, null, null, null, null],
    );

    late List<PlaceLog> logs;

    setUp(() {
      logs = [
        log('tokyo', at: DateTime.utc(2025, 3, 1), location: shibuya),
        log('osaka', at: DateTime.utc(2025, 3, 2), location: namba),
        log('seoul', at: DateTime.utc(2026, 1, 1), location: seoul),
        log('none', at: DateTime.utc(2025, 3, 3), loadout: '아침 산책'),
      ];
    });

    List<String> ids(PhotoFilter filter) => [
      for (final e in queryPlaceLogs(logs, places, filter)) e.log.id,
    ];

    test('조건이 없으면 전부 최신순', () {
      expect(ids(const PhotoFilter()), ['seoul', 'none', 'osaka', 'tokyo']);
    });

    test('연도는 그때 기기의 현지 시각으로 본다', () {
      logs.add(
        log(
          'new-year',
          at: DateTime.utc(2025, 12, 31, 16),
          offset: const Duration(hours: 9),
        ),
      );

      expect(ids(const PhotoFilter(year: 2026)), ['seoul', 'new-year']);
    });

    test('지역 조건이 있으면 위치 없는 기록은 빠진다', () {
      expect(ids(const PhotoFilter(country: '일본')), ['osaka', 'tokyo']);
      expect(ids(const PhotoFilter(country: '일본', admin: '도쿄도')), ['tokyo']);
    });

    test('필름 시뮬레이션·위치 없음 조건은 기록에 쓰지 않는다', () {
      expect(
        ids(const PhotoFilter(films: {eterna}, noLocationOnly: true)),
        hasLength(4),
      );
    });

    test('검색어는 장소·세트 이름·레시피 이름에서 찾는다', () {
      logs.add(log('night', at: DateTime.utc(2025), slot: 'Eterna 밤'));

      expect(ids(const PhotoFilter(text: '진난')), ['tokyo']);
      expect(ids(const PhotoFilter(text: '산책')), ['none']);
      expect(ids(const PhotoFilter(text: 'eterna')), ['night']);
    });

    test('선택지는 기록의 연도(현지 시각)와 지역으로 만든다', () {
      final facets = placeLogFacets(
        logs,
        places,
        const PhotoFilter(country: '일본'),
      );

      expect(facets.years, [2026, 2025]);
      expect(facets.countries, containsAll(['일본', '대한민국']));
      expect(facets.admins, containsAll(['도쿄도', '오사카부']));
      expect(facets.films, isEmpty);
    });

    test('항목은 장소를 함께 준다', () {
      final entry = queryPlaceLogs(
        logs,
        places,
        const PhotoFilter(text: '진난'),
      ).single;

      expect(entry.place?.locality, '시부야구');
    });
  });
}
