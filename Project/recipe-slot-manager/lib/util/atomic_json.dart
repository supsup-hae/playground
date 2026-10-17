import 'dart:convert';
import 'dart:io';

/// [json] 을 [file] 에 쓴다. 쓰는 도중 멈춰도 잘린 파일이 남지 않도록 임시 파일에
/// 쓰고 옮긴다.
Future<File> writeJsonAtomically(File file, Object? json) async {
  await file.parent.create(recursive: true);
  final temp = File('${file.path}.tmp');
  await temp.writeAsString(
    const JsonEncoder.withIndent('  ').convert(json),
    flush: true,
  );
  return temp.rename(file.path);
}
