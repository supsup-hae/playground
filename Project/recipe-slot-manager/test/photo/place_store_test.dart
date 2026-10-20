import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/photo/place.dart';
import 'package:recipe_slot_manager/photo/place_store.dart';

void main() {
  late Directory root;
  final now = DateTime.utc(2026, 10, 20, 9);

  PlaceStore newStore() => PlaceStore(root, clock: () => now);

  setUp(() => root = Directory.systemTemp.createTempSync('place_store_test'));
  tearDown(() => root.deleteSync(recursive: true));

  test('저장했다가 다시 읽고, 모르는 키는 null', () async {
    final store = newStore();
    await store.save('35.6587,139.7005', const Place(country: '일본'));
    await store.save('0.0000,0.0000', const Place());

    final read = newStore();
    await read.load();

    expect(read.place('35.6587,139.7005')?.country, '일본');
    expect(read.place('0.0000,0.0000')?.isEmpty, isTrue);
    expect(read.place('1.0000,1.0000'), isNull);
    expect(read.contains('0.0000,0.0000'), isTrue);
  });

  test('위치로 찾는다', () async {
    final store = newStore();
    await store.save('35.6587,139.7005', const Place(country: '일본'));

    expect(
      store.placeOf((latitude: 35.65871, longitude: 139.70046))?.country,
      '일본',
    );
    expect(store.placeOf(null), isNull);
  });

  test('파일이 없으면 빈 캐시', () async {
    final store = newStore();
    await store.load();

    expect(store.contains('35.6587,139.7005'), isFalse);
  });

  test('깨진 파일은 옮기고 빈 캐시로 시작한다', () async {
    final file = File(p.join(root.path, 'places.json'))
      ..writeAsStringSync('{"places": []}');
    final store = newStore();

    await store.load();

    expect(file.existsSync(), isFalse);
    expect(store.loadErrors.single, startsWith('places.json 읽기 실패'));
  });
}
