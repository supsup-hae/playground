import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/ui/photo_thumbnail.dart';

import '../support/exif_builder.dart';
import '../support/test_app.dart';

void main() {
  late TestApp app;
  final thumbnail = Uint8List.fromList([0xFF, 0xD8, 1, 0xFF, 0xD9]);

  IndexedPhoto photo({int modifiedMs = 1}) => IndexedPhoto(
    sourceId: 's1',
    file: (id: 'a.jpg', name: 'a.jpg', size: 100, modifiedMs: modifiedMs),
  );

  setUp(() async {
    app = TestApp();
    await app.photoStore.saveSource(
      const PhotoSource(
        id: 's1',
        kind: PhotoSourceKind.folder,
        name: 'X-T5',
        location: '/photos',
      ),
    );
    app.photoReader.put('a.jpg', bytes: jpegWithExif(thumbnail: thumbnail));
  });
  tearDown(() => app.dispose());

  test('같은 사진은 한 번만 읽고, 수정 시각이 바뀌면 다시 읽는다', () async {
    final thumbnails = PhotoThumbnails(app.photoIndexer);

    expect(await thumbnails.of(photo()), thumbnail);
    await thumbnails.of(photo());
    await thumbnails.of(photo(modifiedMs: 2));

    expect(app.photoReader.reads, ['a.jpg', 'a.jpg']);
  });

  test('읽지 못한 사진은 기억하지 않고 다음에 다시 읽는다', () async {
    final thumbnails = PhotoThumbnails(app.photoIndexer);
    app.photoReader.readError = const PhotoSourceException('폴더를 찾을 수 없습니다');

    expect(await thumbnails.of(photo()), isNull);
    app.photoReader.readError = null;

    expect(await thumbnails.of(photo()), thumbnail);
  });

  test('썸네일이 없는 사진은 없음으로 기억한다', () async {
    app.photoReader.put('a.jpg', bytes: jpegWithExif());
    final thumbnails = PhotoThumbnails(app.photoIndexer);

    expect(await thumbnails.of(photo()), isNull);
    expect(await thumbnails.of(photo()), isNull);
    expect(app.photoReader.reads, ['a.jpg']);
  });
}
