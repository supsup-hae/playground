import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/photo/place_log.dart';
import 'package:recipe_slot_manager/photo/place_log_store.dart';

void main() {
  late Directory root;
  final now = DateTime.utc(2026, 10, 20, 9);

  PlaceLogStore newStore() => PlaceLogStore(root, clock: () => now);

  PlaceLog log(String id, DateTime at) => PlaceLog(
    id: id,
    loggedAt: at,
    utcOffset: Duration.zero,
    loadoutId: 'loadout-1',
    loadoutName: '세트',
    slots: List.filled(7, null),
  );

  setUp(() => root = Directory.systemTemp.createTempSync('place_log_store'));
  tearDown(() => root.deleteSync(recursive: true));

  test('저장했다가 다시 읽으면 최신순', () async {
    final store = newStore();
    await store.add(log('old', DateTime.utc(2026, 10, 1)));
    await store.add(log('new', DateTime.utc(2026, 10, 2)));

    final read = newStore();
    await read.load();

    expect(read.logs.map((l) => l.id), ['new', 'old']);
  });

  test('파일이 없으면 빈 기록', () async {
    final store = newStore();
    await store.load();

    expect(store.logs, isEmpty);
  });

  test('깨진 파일은 옮기고 빈 기록으로 시작한다', () async {
    final file = File(p.join(root.path, 'place_logs.json'))
      ..writeAsStringSync('{"logs": {}}');
    final store = newStore();

    await store.load();

    expect(file.existsSync(), isFalse);
    expect(store.logs, isEmpty);
    expect(store.loadErrors.single, startsWith('place_logs.json 읽기 실패'));
  });
}
