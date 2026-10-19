import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/import/jpeg_exif.dart';
import 'package:recipe_slot_manager/photo/folder_reader.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late List<MethodCall> calls;
  late Future<Object?> Function(MethodCall call) handler;

  PhotoSource sourceAt(String path, {String? bookmark}) => PhotoSource(
    id: 's1',
    kind: PhotoSourceKind.folder,
    name: p.basename(path),
    location: path,
    bookmark: bookmark,
  );

  void write(String relative, [int length = 10]) {
    File(p.join(root.path, relative))
      ..createSync(recursive: true)
      ..writeAsBytesSync(Uint8List(length));
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('folder_reader_test');
    calls = [];
    handler = (_) async => null;
    messenger.setMockMethodCallHandler(bookmarkChannel, (call) {
      calls.add(call);
      return handler(call);
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(bookmarkChannel, null);
    root.deleteSync(recursive: true);
  });

  test('하위 폴더까지 JPEG 만 찾고 숨김 파일·폴더는 뺀다', () async {
    write('a.jpg');
    write('2026/b.JPG');
    write('2026/c.jpeg');
    write('d.png');
    write('.e.jpg');
    write('.thumbs/f.jpg');

    final files = await FolderReader().list(sourceAt(root.path));

    expect(files.map((f) => f.id).toList()..sort(), [
      '2026/b.JPG',
      '2026/c.jpeg',
      'a.jpg',
    ]);
    final a = files.firstWhere((f) => f.id == 'a.jpg');
    expect((a.name, a.size), ('a.jpg', 10));
    expect(a.modifiedMs, greaterThan(0));
  });

  test('앞부분은 jpegHeadBytes 만 읽는다', () async {
    write('big.jpg', jpegHeadBytes + 1000);
    write('small.jpg', 20);
    final reader = FolderReader();
    final source = sourceAt(root.path);
    final files = await reader.list(source);

    final big = await reader.readHead(
      source,
      files.firstWhere((f) => f.id == 'big.jpg'),
    );
    final small = await reader.readHead(
      source,
      files.firstWhere((f) => f.id == 'small.jpg'),
    );

    expect(big.bytes, hasLength(jpegHeadBytes));
    expect(small.bytes, hasLength(20));
    expect(big.locationRedacted, isFalse);
  });

  test('폴더가 없으면 PhotoSourceException', () async {
    await expectLater(
      FolderReader().list(sourceAt(p.join(root.path, '없음'))),
      throwsA(isA<PhotoSourceException>()),
    );
  });

  test('읽을 수 없는 하위 폴더가 있으면 PhotoSourceException', () async {
    write('locked/a.jpg');
    final locked = p.join(root.path, 'locked');
    Process.runSync('chmod', ['000', locked]);
    addTearDown(() => Process.runSync('chmod', ['755', locked]));

    await expectLater(
      FolderReader().list(sourceAt(root.path)),
      throwsA(isA<PhotoSourceException>()),
    );
  });

  test('사라진 파일을 읽으면 PhotoSourceException', () async {
    final source = sourceAt(root.path);

    await expectLater(
      FolderReader().readHead(source, (
        id: 'gone.jpg',
        name: 'gone.jpg',
        size: 1,
        modifiedMs: 1,
      )),
      throwsA(isA<PhotoSourceException>()),
    );
  });

  group('북마크 (macOS)', () {
    test('북마크를 풀어 얻은 경로를 읽고, 다음 목록 전에 접근을 닫는다', () async {
      write('a.jpg');
      handler = (call) async => switch (call.method) {
        'resolve' => {'path': root.path, 'stale': false},
        _ => null,
      };
      final reader = FolderReader(useBookmarks: true);
      final source = sourceAt('/old', bookmark: 'AQID');

      final files = await reader.list(source);
      await reader.list(source);

      expect(files.single.id, 'a.jpg');
      expect(calls.map((c) => c.method), ['resolve', 'stop', 'resolve']);
      expect(calls.first.arguments, Uint8List.fromList([1, 2, 3]));
      expect(calls[1].arguments, root.path);
    });

    test('오래된 북마크면 새 북마크와 경로로 출처를 갱신한다', () async {
      handler = (call) async => switch (call.method) {
        'resolve' => {
          'path': root.path,
          'stale': true,
          'bookmark': Uint8List.fromList([9]),
        },
        _ => null,
      };
      PhotoSource? renewed;
      final reader = FolderReader(
        useBookmarks: true,
        onSourceRenewed: (s) async => renewed = s,
      );

      await reader.list(sourceAt('/old', bookmark: 'AQID'));

      expect(renewed?.bookmark, 'CQ==');
      expect(renewed?.location, root.path);
    });

    test('북마크를 풀지 못하면 PhotoSourceException', () async {
      handler = (_) async =>
          throw PlatformException(code: 'bookmark', message: 'not found');

      await expectLater(
        FolderReader(useBookmarks: true).list(sourceAt('/x', bookmark: 'AQID')),
        throwsA(isA<PhotoSourceException>()),
      );
    });

    test('폴더를 고르면 북마크를 만들어 출처로 돌려준다', () async {
      handler = (call) async => Uint8List.fromList([1, 2, 3]);

      final source = await folderSource(
        root.path,
        useBookmarks: true,
        id: 'new',
      );

      expect(calls.single.method, 'create');
      expect(calls.single.arguments, root.path);
      expect(source.toJson(), {
        'id': 'new',
        'kind': 'folder',
        'name': p.basename(root.path),
        'location': root.path,
        'bookmark': 'AQID',
      });
    });
  });
}
