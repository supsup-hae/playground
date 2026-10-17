import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
