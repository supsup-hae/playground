import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/camera/slot_backup_store.dart';
import 'package:recipe_slot_manager/camera/slot_snapshot.dart';

void main() {
  late Directory root;
  late DateTime now;
  late SlotBackupStore store;

  final slots = [
    for (var slot = 1; slot <= 7; slot++)
      SlotSnapshot(
        slot: slot,
        name: 'C$slot',
        props: {
          0xD192: Uint8List.fromList([slot, 0]),
        },
      ),
  ];

  setUp(() {
    root = Directory.systemTemp.createTempSync('slot_backup_test');
    now = DateTime.utc(2026, 10, 16, 9, 30, 5, 123);
    store = SlotBackupStore(
      Directory(p.join(root.path, 'backups')),
      clock: () => now,
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('없던 디렉터리를 만들고 시각이 들어간 이름으로 저장한다', () async {
    final file = await store.save('X-T5', slots);

    expect(p.basename(file.path), 'slots-20261016-093005-123.json');
    expect(file.existsSync(), isTrue);
  });

  test('저장한 백업을 같은 내용으로 불러온다', () async {
    final file = await store.save('X-T5', slots);

    final backup = await store.load(file);

    expect(backup.model, 'X-T5');
    expect(backup.createdAt, now);
    expect(backup.slots.map((s) => s.toJson()), slots.map((s) => s.toJson()));
  });

  test('목록은 최신 백업이 먼저 온다', () async {
    final older = await store.save('X-T5', slots);
    now = now.add(const Duration(minutes: 1));
    final newer = await store.save('X-T5', slots);

    final files = await store.list();

    expect(files.map((f) => f.path), [newer.path, older.path]);
  });

  test('저장 뒤 임시 파일이 남지 않는다', () async {
    await store.save('X-T5', slots);

    final names = Directory(p.join(root.path, 'backups'))
        .listSync()
        .map((e) => p.basename(e.path));
    expect(names, ['slots-20261016-093005-123.json']);
  });

  group('load 는 형식이 맞지 않는 백업을 FormatException 으로 거른다', () {
    Future<File> write(String content) async {
      final file = File(p.join(root.path, 'bad.json'));
      return file.writeAsString(content);
    }

    test('JSON 이 아님', () async {
      final file = await write('{not json');
      expect(() => store.load(file), throwsFormatException);
    });

    test('필드 타입이 다름', () async {
      final file = await write('{"model": 1, "createdAt": "x", "slots": []}');
      expect(() => store.load(file), throwsFormatException);
    });

    test('같은 슬롯이 두 번 있음', () async {
      final slot = '{"slot": 1, "name": "C1", "props": {}}';
      final file = await write(
        '{"model": "X-T5", "createdAt": "2026-10-16T09:30:05.123Z", '
        '"slots": [$slot, $slot]}',
      );
      expect(() => store.load(file), throwsFormatException);
    });
  });

  test('디렉터리가 없으면 빈 목록이다', () async {
    expect(await store.list(), isEmpty);
  });
}
