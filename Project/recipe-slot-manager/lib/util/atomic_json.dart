import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

/// [json] 을 [file] 에 쓴다. 쓰는 도중 멈춰도 잘린 파일이 남지 않도록 임시 파일에
/// 쓰고 옮긴다. 같은 파일에 동시에 써도 임시 파일이 겹치지 않는다.
Future<File> writeJsonAtomically(File file, Object? json) async {
  await file.parent.create(recursive: true);
  final suffix = Random().nextInt(1 << 32).toRadixString(16);
  final temp = File('${file.path}.$suffix.tmp');
  await temp.writeAsString(
    const JsonEncoder.withIndent('  ').convert(json),
    flush: true,
  );
  return temp.rename(file.path);
}

/// [file] 을 읽어 [parse] 결과를 돌려준다. 파일이 없으면 null. JSON 이 아니거나 [parse] 가
/// [FormatException] 을 던지면, 덮어쓰지 않도록 `<이름>.corrupt-<now>` 로 옮기고 [errors] 에
/// 설명을 더한 뒤 null.
Future<T?> readJsonFile<T>(
  File file,
  T Function(Object? json) parse, {
  required DateTime now,
  required List<String> errors,
}) async {
  if (!await file.exists()) return null;
  try {
    return parse(jsonDecode(await file.readAsString()));
  } on FormatException catch (e) {
    final stamp = now.toUtc().toIso8601String().replaceAll(':', '-');
    final moved = await file.rename('${file.path}.corrupt-$stamp');
    errors.add(
      '${p.basename(file.path)} 읽기 실패, ${p.basename(moved.path)} 로 옮김: '
      '${e.message}',
    );
    return null;
  }
}
