import 'dart:typed_data';

import 'package:recipe_slot_manager/photo/photo_source.dart';

import 'exif_builder.dart';

/// 촬영 시각과 필름 시뮬레이션(FilmMode)만 든 후지 JPEG 앞부분.
Uint8List fujiJpeg({int filmMode = 0x700, int imageCount = 1}) => jpegWithExif(
  ifd0Tags: {0x0110: (tiffAscii, asciiValue('X-T5'))},
  exifTags: {
    0x9003: (tiffAscii, asciiValue('2026:10:11 15:26:10')),
    0x9011: (tiffAscii, asciiValue('+09:00')),
  },
  makerNote: fujiMakerNote({
    0x1401: (tiffShort, [filmMode]),
    0x1438: (tiffShort, [imageCount]),
  }),
);

/// 메모리 안 출처. [files] 를 바꾸면 다음 [list] 에 반영된다.
class FakePhotoReader implements PhotoSourceReader {
  final files = <String, ({PhotoFile file, Uint8List bytes, bool redacted})>{};
  final reads = <String>[];
  final closed = <String>[];
  Object? listError;

  void put(
    String id, {
    int size = 100,
    int modifiedMs = 1,
    Uint8List? bytes,
    bool redacted = false,
  }) => files[id] = (
    file: (id: id, name: id, size: size, modifiedMs: modifiedMs),
    bytes: bytes ?? fujiJpeg(),
    redacted: redacted,
  );

  @override
  Future<List<PhotoFile>> list(PhotoSource source) async {
    if (listError case final error?) throw error;
    return [for (final entry in files.values) entry.file];
  }

  @override
  Future<void> close(PhotoSource source) async => closed.add(source.id);

  @override
  Future<PhotoHead> readHead(PhotoSource source, PhotoFile file) async {
    reads.add(file.id);
    final entry = files[file.id]!;
    return (bytes: entry.bytes, locationRedacted: entry.redacted);
  }
}
