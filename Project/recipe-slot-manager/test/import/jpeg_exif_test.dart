import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/import/jpeg_exif.dart';
import 'package:recipe_slot_manager/import/recipe_import.dart';

import '../support/exif_builder.dart';

void main() {
  group('readExif', () {
    test('IFD0·Exif·GPS IFD 를 함께 돌려준다', () {
      final exif = readExif(
        jpegWithExif(
          ifd0Tags: {0x0110: (tiffAscii, asciiValue('X-T5'))},
          exifTags: {0x9003: (tiffAscii, asciiValue('2026:10:11 15:26:10'))},
          gpsTags: {0x0001: (tiffAscii, asciiValue('N'))},
        ),
      );

      expect(ifdString(exif.tiff, exif.ifd0[0x0110]!), 'X-T5');
      expect(ifdString(exif.tiff, exif.exif![0x9003]!), '2026:10:11 15:26:10');
      expect(ifdString(exif.tiff, exif.gps![0x0001]!), 'N');
    });

    test('GPS IFD 가 없으면 gps 는 null', () {
      expect(readExif(jpegWithExif()).gps, isNull);
    });

    test('GPS IFD 위치가 TIFF 밖이면 gps 만 null 이고 MakerNote 는 읽는다', () {
      final jpeg = jpegWithExif(
        makerNote: fujiMakerNote({
          0x1401: (tiffShort, [0x700]),
        }),
        gpsTags: {0x0001: (tiffAscii, asciiValue('N'))},
        brokenGpsPointer: true,
      );

      expect(readExif(jpeg).gps, isNull);
      expect(readMakerNote(jpeg), isNotEmpty);
    });

    test('Exif IFD 위치 값이 하나가 아니면 깨진 파일로 본다', () {
      expect(
        () => readExif(jpegWithExif(brokenExifPointer: true)),
        throwsA(isA<ImportException>()),
      );
    });
  });

  group('ifdRationals', () {
    test('RATIONAL 3개를 항목 밖 값 영역에서 읽는다', () {
      final exif = readExif(
        jpegWithExif(
          gpsTags: {
            0x0002: (tiffRational, [35, 1, 39, 1, 312, 10]),
          },
        ),
      );

      final entry = exif.gps![0x0002]!;
      expect(entry.count, 3);
      expect(ifdRationals(exif.view, entry, exif.endian), [35, 39, 31.2]);
    });

    test('분모가 0 인 값은 null', () {
      final exif = readExif(
        jpegWithExif(
          gpsTags: {
            0x0002: (tiffRational, [0, 0, 39, 1, 0, 0]),
          },
        ),
      );

      expect(ifdRationals(exif.view, exif.gps![0x0002]!, exif.endian), [
        null,
        39,
        null,
      ]);
    });

    test('RATIONAL 이 아닌 항목은 깨진 파일로 본다', () {
      final exif = readExif(
        jpegWithExif(
          gpsTags: {
            0x0002: (tiffShort, [35, 39, 31]),
          },
        ),
      );

      expect(
        () => ifdRationals(exif.view, exif.gps![0x0002]!, exif.endian),
        throwsA(isA<ImportException>()),
      );
    });

    test('빅 엔디언에서도 같다', () {
      final exif = readExif(
        jpegWithExif(
          bigEndian: true,
          gpsTags: {
            0x0002: (tiffRational, [35, 1, 39, 1, 312, 10]),
          },
        ),
      );

      expect(ifdRationals(exif.view, exif.gps![0x0002]!, exif.endian), [
        35,
        39,
        31.2,
      ]);
    });
  });

  group('readExifThumbnail', () {
    test('IFD1 의 JPEG 썸네일을 꺼낸다', () {
      final thumbnail = Uint8List.fromList([0xFF, 0xD8, 1, 2, 3, 0xFF, 0xD9]);

      expect(readExifThumbnail(jpegWithExif(thumbnail: thumbnail)), thumbnail);
    });

    test('빅 엔디언에서도 꺼낸다', () {
      final thumbnail = Uint8List.fromList([0xFF, 0xD8, 9, 0xFF, 0xD9]);

      expect(
        readExifThumbnail(jpegWithExif(thumbnail: thumbnail, bigEndian: true)),
        thumbnail,
      );
    });

    test('썸네일이 없거나 JPEG 이 아니거나 파일이 잘렸으면 null', () {
      expect(readExifThumbnail(jpegWithExif()), isNull);
      expect(
        readExifThumbnail(
          jpegWithExif(thumbnail: Uint8List.fromList([0, 0, 0])),
        ),
        isNull,
      );
      expect(readExifThumbnail(Uint8List.fromList([1, 2, 3])), isNull);
      final jpeg = jpegWithExif(
        thumbnail: Uint8List.fromList(List.filled(100, 0xFF)..[1] = 0xD8),
      );
      expect(
        readExifThumbnail(Uint8List.sublistView(jpeg, 0, jpeg.length - 60)),
        isNull,
      );
    });
  });

  test('ifdBytes 는 값 바이트 전체를 돌려준다', () {
    final exif = readExif(
      jpegWithExif(
        gpsTags: {
          0x0002: (tiffRational, [35, 1, 39, 1, 312, 10]),
        },
      ),
    );

    expect(ifdBytes(exif.tiff, exif.gps![0x0002]!), hasLength(24));
  });

  test('ifdString 은 첫 NUL 앞까지 읽고 앞뒤 공백을 지운다', () {
    final exif = readExif(
      jpegWithExif(
        ifd0Tags: {
          0x010F: (tiffAscii, [...' FUJIFILM '.codeUnits, 0, 0x41, 0]),
        },
      ),
    );

    expect(ifdString(exif.tiff, exif.ifd0[0x010F]!), 'FUJIFILM');
  });
}
