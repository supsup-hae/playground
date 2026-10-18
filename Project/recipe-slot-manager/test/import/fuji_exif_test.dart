import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/import/fuji_makernote.dart';
import 'package:recipe_slot_manager/import/jpeg_exif.dart';
import 'package:recipe_slot_manager/import/recipe_import.dart';

import '../support/exif_builder.dart';

/// 컬러 레시피 하나: Classic Neg., 그레인 약·대, CC 강, FX 블루 끔, 색온도 5600K
/// R+2 B-4, DR400, H -1.5, S +0.5, 컬러 +3, 샤프니스 -1, NR -4, 클래리티 -3.
final colorTags = <int, (int, List<int>)>{
  0x1401: (tiffShort, [0x800]),
  0x1003: (tiffShort, [0x0C0]),
  0x1001: (tiffShort, [0x82]),
  0x1041: (tiffSLong, [24]),
  0x1040: (tiffSLong, [-8]),
  0x100E: (tiffShort, [0x2E0]),
  0x100F: (tiffSLong, [-3000]),
  0x1047: (tiffSLong, [32]),
  0x104C: (tiffSLong, [32]),
  0x1048: (tiffSLong, [64]),
  0x104E: (tiffSLong, [0]),
  0x1002: (tiffShort, [0xFF0]),
  0x1005: (tiffShort, [5600]),
  0x100A: (tiffSLong, [40, -80]),
  0x1403: (tiffShort, [400]),
};

Map<String, double> decode(Uint8List jpeg) =>
    decodeFujiRecipe(readFujiTags(readMakerNote(jpeg)));

void main() {
  group('readMakerNote', () {
    test('JPEG 이 아니면 ImportException', () {
      expect(
        () => readMakerNote(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47])),
        throwsA(isA<ImportException>()),
      );
    });

    test('Exif 가 없거나 MakerNote 가 없으면 ImportException', () {
      expect(
        () => readMakerNote(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9])),
        throwsA(isA<ImportException>()),
      );
      expect(
        () => readMakerNote(jpegWithExif()),
        throwsA(isA<ImportException>()),
      );
    });

    test('Exif IFD 위치 값이 하나가 아니면 깨진 파일로 본다', () {
      final jpeg = jpegWithExif(
        makerNote: fujiMakerNote(colorTags),
        brokenExifPointer: true,
      );
      expect(() => readMakerNote(jpeg), throwsA(isA<ImportException>()));
    });

    test('세그먼트 길이가 2보다 작으면 깨진 파일로 본다', () {
      for (final length in [0, 1]) {
        final jpeg = Uint8List.fromList([
          0xFF,
          0xD8,
          0xFF,
          0xE1,
          0x00,
          length,
          0xFF,
          0xD9,
        ]);
        expect(
          () => readMakerNote(jpeg),
          throwsA(isA<ImportException>()),
          reason: '길이 $length',
        );
      }
    });

    test('잘린 파일은 ImportException', () {
      final jpeg = jpegWithExif(makerNote: fujiMakerNote(colorTags));
      expect(
        () => readMakerNote(Uint8List.sublistView(jpeg, 0, 40)),
        throwsA(isA<ImportException>()),
      );
    });
  });

  test('후지필름 MakerNote 가 아니면 ImportException', () {
    final note = Uint8List.fromList([
      ...'NIKON\u0000\u0000\u0000'.codeUnits,
      0,
      0,
      0,
      0,
    ]);
    expect(() => readFujiTags(note), throwsA(isA<ImportException>()));
  });

  test('컬러 레시피의 모든 필드를 읽는다', () {
    final jpeg = jpegWithExif(makerNote: fujiMakerNote(colorTags));

    expect(decode(jpeg), {
      'filmSimulation': 0x11,
      'color': 3,
      'sharpness': -1,
      'highlight': -1.5,
      'shadow': 0.5,
      'noiseReduction': -4,
      'clarity': -3,
      'grain': 4,
      'colorChrome': 3,
      'colorChromeFxBlue': 1,
      'whiteBalance': 0x8007,
      'colorTemperature': 5600,
      'wbShiftRed': 2,
      'wbShiftBlue': -4,
      'dynamicRange': 400,
    });
  });

  test('빅 엔디언 TIFF 에서도 같은 결과', () {
    final little = jpegWithExif(makerNote: fujiMakerNote(colorTags));
    final big = jpegWithExif(
      makerNote: fujiMakerNote(colorTags),
      bigEndian: true,
    );

    expect(decode(big), decode(little));
  });

  test('흑백은 Saturation 으로 시뮬레이션을 정하고 컬러 대신 모노 WC·MG 를 읽는다', () {
    final jpeg = jpegWithExif(
      makerNote: fujiMakerNote({
        0x1003: (tiffShort, [0x501]),
        0x1049: (tiffSByte, [2]),
        0x104B: (tiffSByte, [-1]),
      }),
    );

    expect(decode(jpeg), {
      'filmSimulation': 0x0E,
      'monoWarmCool': 2,
      'monoMagentaGreen': -1,
    });
  });

  test('표에 없는 원시 값과 오토가 아닌 WB 의 색온도는 빈칸이다', () {
    final jpeg = jpegWithExif(
      makerNote: fujiMakerNote({
        0x1401: (tiffShort, [0x123]),
        0x1001: (tiffShort, [0x77]),
        0x1002: (tiffShort, [0x100]),
        0x1005: (tiffShort, [5000]),
        0x1047: (tiffSLong, [0]),
      }),
    );

    expect(decode(jpeg), {'whiteBalance': 0x0004, 'grain': 1});
  });
}
