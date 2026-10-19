import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/import/jpeg_exif.dart';
import 'package:recipe_slot_manager/photo/album_reader.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Future<Object?> Function(MethodCall call) handler;
  final reader = AlbumReader();

  const album = PhotoSource(
    id: 's1',
    kind: PhotoSourceKind.album,
    name: 'FUJIFILM XApp',
    location: '-17',
  );

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(photoChannel, (call) {
      calls.add(call);
      return handler(call);
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(photoChannel, null));

  test('권한 요청 결과를 사진·위치로 나눠 돌려준다', () async {
    handler = (_) async => {'images': true, 'location': false};

    final access = await reader.requestAccess();

    expect(calls.single.method, 'requestAccess');
    expect((access.images, access.location), (true, false));
  });

  test('앨범 목록', () async {
    handler = (_) async => [
      {'id': '-17', 'name': 'FUJIFILM XApp', 'count': 1204},
    ];

    final albums = await reader.albums();

    expect(albums.single, (id: '-17', name: 'FUJIFILM XApp', count: 1204));
  });

  test('앨범의 사진 목록을 출처 위치(버킷 id)로 요청한다', () async {
    handler = (_) async => [
      {
        'id': 'content://media/external/images/media/7',
        'name': 'DSCF1422.JPG',
        'size': 4800000,
        'modified': 1760163970000,
      },
    ];

    final files = await reader.list(album);

    expect(calls.single.method, 'photos');
    expect(calls.single.arguments, '-17');
    expect(files.single, (
      id: 'content://media/external/images/media/7',
      name: 'DSCF1422.JPG',
      size: 4800000,
      modifiedMs: 1760163970000,
    ));
  });

  test('앞부분은 jpegHeadBytes 만 요청하고, 위치가 가려졌는지 함께 받는다', () async {
    handler = (_) async => {
      'bytes': Uint8List.fromList([0xFF, 0xD8]),
      'locationRedacted': true,
    };
    const file = (id: 'content://x/7', name: 'a.jpg', size: 1, modifiedMs: 1);

    final head = await reader.readHead(album, file);

    expect(calls.single.method, 'readHead');
    expect(calls.single.arguments, {
      'id': 'content://x/7',
      'length': jpegHeadBytes,
    });
    expect(head.bytes, [0xFF, 0xD8]);
    expect(head.locationRedacted, isTrue);
  });

  test('권한이 없으면 접근 허용 안내', () async {
    handler = (_) async =>
        throw PlatformException(code: 'permission', message: 'denied');

    await expectLater(
      reader.list(album),
      throwsA(
        isA<PhotoSourceException>().having(
          (e) => e.message,
          'message',
          '사진 접근이 허용되지 않았습니다',
        ),
      ),
    );
  });

  test('그 밖의 플랫폼 오류와 채널 없음도 PhotoSourceException', () async {
    handler = (_) async => throw PlatformException(code: 'io', message: 'boom');
    await expectLater(reader.albums(), throwsA(isA<PhotoSourceException>()));

    messenger.setMockMethodCallHandler(photoChannel, null);
    await expectLater(reader.albums(), throwsA(isA<PhotoSourceException>()));
  });
}
