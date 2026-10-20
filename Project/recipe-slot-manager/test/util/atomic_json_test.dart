import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/util/atomic_json.dart';

void main() {
  late Directory root;
  final now = DateTime.utc(2026, 10, 20, 9, 30);

  setUp(() => root = Directory.systemTemp.createTempSync('atomic_json_test'));
  tearDown(() => root.deleteSync(recursive: true));

  int countOf(Object? json) => switch (json) {
    {'count': final int count} => count,
    _ => throw const FormatException('count 없음'),
  };

  test('쓴 파일을 읽어 parse 결과를 돌려준다', () async {
    final file = File(p.join(root.path, 'a.json'));
    await writeJsonAtomically(file, {'count': 3});
    final errors = <String>[];

    expect(await readJsonFile(file, countOf, now: now, errors: errors), 3);
    expect(errors, isEmpty);
  });

  test('파일이 없으면 null, 오류 없음', () async {
    final errors = <String>[];

    final read = await readJsonFile(
      File(p.join(root.path, 'none.json')),
      countOf,
      now: now,
      errors: errors,
    );

    expect(read, isNull);
    expect(errors, isEmpty);
  });

  test('JSON 이 아니거나 parse 가 거부하면 옮기고 이유를 남긴 뒤 null', () async {
    for (final (name, body) in [('broken.json', '{'), ('wrong.json', '{}')]) {
      final file = File(p.join(root.path, name))..writeAsStringSync(body);
      final errors = <String>[];

      final read = await readJsonFile(file, countOf, now: now, errors: errors);

      expect(read, isNull);
      expect(file.existsSync(), isFalse);
      expect(
        File('${file.path}.corrupt-2026-10-20T09-30-00.000Z').existsSync(),
        isTrue,
      );
      expect(errors.single, startsWith('$name 읽기 실패, $name.corrupt-'));
    }
  });
}
