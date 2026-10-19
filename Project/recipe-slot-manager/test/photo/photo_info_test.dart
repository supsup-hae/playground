import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/import/jpeg_exif.dart';
import 'package:recipe_slot_manager/import/recipe_import.dart';
import 'package:recipe_slot_manager/photo/photo_info.dart';

import '../support/exif_builder.dart';

/// 2026-10-11 15:26:10 +09:00 에 X-T5 로 찍은 사진의 IFD0·Exif 태그.
final ifd0 = {0x0110: (tiffAscii, asciiValue('X-T5'))};
final shot = {
  0x9003: (tiffAscii, asciiValue('2026:10:11 15:26:10')),
  0x9011: (tiffAscii, asciiValue('+09:00')),
};

/// 북위 35°39'31.2", 동경 139°42'0".
final tokyo = {
  0x0001: (tiffAscii, asciiValue('N')),
  0x0002: (tiffRational, [35, 1, 39, 1, 312, 10]),
  0x0003: (tiffAscii, asciiValue('E')),
  0x0004: (tiffRational, [139, 1, 42, 1, 0, 1]),
};

PhotoInfo read({
  Map<int, (int, List<int>)>? gps,
  Map<int, (int, List<int>)>? exif,
  Uint8List? makerNote,
  bool bigEndian = false,
}) => readPhotoInfo(
  jpegWithExif(
    ifd0Tags: ifd0,
    exifTags: exif ?? shot,
    gpsTags: gps,
    makerNote: makerNote,
    bigEndian: bigEndian,
  ),
);

void main() {
  group('위치', () {
    test('북위·동경을 도 단위로 읽는다', () {
      final location = read(gps: tokyo).location!;

      expect(location.latitude, closeTo(35.6587, 1e-4));
      expect(location.longitude, closeTo(139.7, 1e-4));
    });

    test('남위·서경은 음수다', () {
      final location = read(
        gps: {
          ...tokyo,
          0x0001: (tiffAscii, asciiValue('S')),
          0x0003: (tiffAscii, asciiValue('W')),
        },
      ).location!;

      expect(location.latitude, closeTo(-35.6587, 1e-4));
      expect(location.longitude, closeTo(-139.7, 1e-4));
    });

    test('표본처럼 값이 모두 0 인 GPS 는 위치 없음', () {
      final empty = read(
        gps: {
          0x0000: (tiffByte, [0, 0, 0, 0]),
          0x0001: (tiffAscii, [0, 0]),
          0x0002: (tiffRational, [0, 0, 0, 0, 0, 0]),
          0x0003: (tiffAscii, [0, 0]),
          0x0004: (tiffRational, [0, 0, 0, 0, 0, 0]),
        },
      );

      expect(empty.location, isNull);
    });

    test('GPS IFD 가 없으면 위치 없음이고 나머지는 읽는다', () {
      final info = read();

      expect(info.location, isNull);
      expect(info.model, 'X-T5');
    });

    test('분모가 0 인 값이 하나라도 있으면 위치 없음', () {
      final info = read(
        gps: {
          ...tokyo,
          0x0002: (tiffRational, [35, 1, 0, 0, 0, 1]),
        },
      );

      expect(info.location, isNull);
    });

    test('위도 90° 를 넘으면 위치 없음', () {
      final info = read(
        gps: {
          ...tokyo,
          0x0002: (tiffRational, [95, 1, 0, 1, 0, 1]),
        },
      );

      expect(info.location, isNull);
    });

    test('좌표가 RATIONAL 형식이 아니면 위치 없음이고 나머지는 읽는다', () {
      final info = read(
        gps: {
          ...tokyo,
          0x0002: (tiffShort, [35, 39, 31]),
        },
      );

      expect(info.location, isNull);
      expect(info.model, 'X-T5');
    });

    test('위도·경도가 둘 다 0 이면 위치 없음', () {
      final info = read(
        gps: {
          ...tokyo,
          0x0002: (tiffRational, [0, 1, 0, 1, 0, 1]),
          0x0004: (tiffRational, [0, 1, 0, 1, 0, 1]),
        },
      );

      expect(info.location, isNull);
    });
  });

  group('촬영 시각', () {
    test('DateTimeOriginal 과 OffsetTimeOriginal 을 읽는다', () {
      final info = read();

      expect(info.shotAt, DateTime.utc(2026, 10, 11, 15, 26, 10));
      expect(info.utcOffset, const Duration(hours: 9));
    });

    test('음의 시간대', () {
      final info = read(
        exif: {...shot, 0x9011: (tiffAscii, asciiValue('-05:30'))},
      );

      expect(info.utcOffset, const Duration(hours: -5, minutes: -30));
    });

    test('시간대가 없으면 시각만 읽고 시간대는 null', () {
      final info = read(exif: {0x9003: shot[0x9003]!});

      expect(info.shotAt, DateTime.utc(2026, 10, 11, 15, 26, 10));
      expect(info.utcOffset, isNull);
    });

    test('없는 날짜·시각은 null', () {
      for (final text in [
        '2026:13:01 10:00:00',
        '2026:02:30 10:00:00',
        '2026:10:11 24:00:00',
      ]) {
        final info = read(exif: {0x9003: (tiffAscii, asciiValue(text))});

        expect(info.shotAt, isNull, reason: text);
      }
    });

    test('범위 밖 시간대는 null', () {
      final info = read(
        exif: {...shot, 0x9011: (tiffAscii, asciiValue('+09:75'))},
      );

      expect(info.utcOffset, isNull);
    });

    test('빈 시각은 null', () {
      final info = read(
        exif: {0x9003: (tiffAscii, asciiValue('0000:00:00 00:00:00'))},
      );

      expect(info.shotAt, isNull);
    });
  });

  group('후지 정보', () {
    final fuji = fujiMakerNote({
      0x1401: (tiffShort, [0x700]),
      0x1438: (tiffShort, [1422]),
    });

    test('필름 시뮬레이션, 촬영 번호, 판별 키', () {
      final info = read(makerNote: fuji);

      expect(info.recipe['filmSimulation'], 0x10);
      expect(info.imageCount, 1422);
      expect(info.key, 'X-T5|2026-10-11T15:26:10+09:00|1422');
    });

    test('빅 엔디언에서도 같다', () {
      final little = read(makerNote: fuji, gps: tokyo);
      final big = read(makerNote: fuji, gps: tokyo, bigEndian: true);

      expect(big.key, little.key);
      expect(big.location, little.location);
      expect(big.recipe, little.recipe);
    });

    test('후지가 아닌 MakerNote 는 레시피 없이 읽는다', () {
      final info = read(
        makerNote: Uint8List.fromList([
          ...'NIKON\u0000\u0000\u0000'.codeUnits,
          0,
          0,
          0,
          0,
        ]),
      );

      expect(info.recipe, isEmpty);
      expect(info.imageCount, isNull);
      expect(info.key, isNull);
    });

    test('MakerNote 가 없으면 레시피 없음', () {
      expect(read().recipe, isEmpty);
    });

    test('시간대가 없으면 판별 키는 null', () {
      final info = read(makerNote: fuji, exif: {0x9003: shot[0x9003]!});

      expect(info.key, isNull);
    });
  });

  group('XApp 으로 받은 X-T5 표본 (test/fixtures/x_t5_eterna.jpg)', () {
    final fixture = File('test/fixtures/x_t5_eterna.jpg').readAsBytesSync();

    test('Eterna, 위치 없음, 촬영 시각·시간대, 촬영 번호', () {
      final info = readPhotoInfo(fixture);

      expect(info.recipe['filmSimulation'], 0x10);
      expect(info.location, isNull);
      expect(info.shotAt, DateTime.utc(2026, 10, 11, 15, 26, 10));
      expect(info.utcOffset, const Duration(hours: 9));
      expect(info.key, 'X-T5|2026-10-11T15:26:10+09:00|1422');
    });

    test('카메라·렌즈 일련번호가 지워져 있다', () {
      final exif = readExif(fixture);

      for (final tag in [0xA431, 0xA435]) {
        expect(ifdString(exif.tiff, exif.exif![tag]!), isEmpty);
      }
    });
  });

  test('JPEG 이 아니면 ImportException', () {
    expect(
      () => readPhotoInfo(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47])),
      throwsA(isA<ImportException>()),
    );
  });
}
