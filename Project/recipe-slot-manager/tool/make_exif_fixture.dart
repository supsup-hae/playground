// 실제 JPEG 에서 EXIF(APP1)만 남긴 시험 자료를 만든다.
//
// dart run tool/make_exif_fixture.dart <원본.jpg> <결과.jpg>
//
// 소유자 이름·카메라·렌즈 일련번호(Exif 0xA430·0xA431·0xA435), 작성자·저작권(IFD0 0x013B·0x8298),
// MakerNote 일련번호(0x0010), IFD1 썸네일의 값 바이트를 0 으로 채운다.
// 바이트 길이와 위치는 그대로 두어 IFD 위치가 바뀌지 않는다.
// GPS IFD 값에 0 이 아닌 바이트가 있거나 GPS IFD 를 읽을 수 없으면 거부한다.
import 'dart:io';
import 'dart:typed_data';

import 'package:recipe_slot_manager/import/jpeg_exif.dart';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      '사용법: dart run tool/make_exif_fixture.dart <원본.jpg> <결과.jpg>',
    );
    exit(64);
  }
  final source = File(args[0]).readAsBytesSync();
  final exif = readExif(source);
  final gps = exif.gps;
  final hasGps = gps == null
      ? exif.ifd0.containsKey(0x8825)
      : gps.values.any((e) => ifdBytes(exif.tiff, e).any((b) => b != 0));
  if (hasGps) {
    stderr.writeln('위치가 든 사진은 시험 자료로 만들지 않는다');
    exit(1);
  }

  // tiff 는 원본 버퍼의 일부다. APP1 은 TIFF 앞 10바이트(FF E1, 길이, "Exif\0\0")부터.
  final app1Start = exif.tiff.offsetInBytes - 10;
  final app1 = Uint8List.fromList(
    source.sublist(app1Start, exif.tiff.offsetInBytes + exif.tiff.length),
  );
  final tiff = Uint8List.sublistView(app1, 10);
  final view = ByteData.sublistView(tiff);

  void blank(int start, int length) => tiff.fillRange(start, start + length, 0);

  final personal = [
    for (final tag in [0xA430, 0xA431, 0xA435]) exif.exif?[tag],
    for (final tag in [0x013B, 0x8298]) exif.ifd0[tag],
  ].nonNulls;
  for (final entry in personal) {
    blank(entry.offset, ifdBytes(exif.tiff, entry).length);
  }

  final makerNote = exif.exif?[0x927C];
  if (makerNote != null) {
    final note = ByteData.sublistView(
      tiff,
      makerNote.offset,
      makerNote.offset + makerNote.count,
    );
    final tags = readIfd(note, note.getUint32(8, Endian.little), Endian.little);
    final internalSerial = tags[0x0010];
    if (internalSerial != null) {
      blank(makerNote.offset + internalSerial.offset, internalSerial.count);
    }
  }

  final ifd0At = view.getUint32(4, exif.endian);
  final ifd1At = view.getUint32(
    ifd0At + 2 + 12 * view.getUint16(ifd0At, exif.endian),
    exif.endian,
  );
  if (ifd1At != 0) {
    final ifd1 = readIfd(view, ifd1At, exif.endian);
    final (start, length) = (ifd1[0x0201], ifd1[0x0202]);
    if (start != null && length != null) {
      blank(
        ifdValues(view, start, exif.endian).first,
        ifdValues(view, length, exif.endian).first,
      );
    }
  }

  for (var i = 0; i + 2 < tiff.length; i++) {
    if (tiff[i] == 0xFF && tiff[i + 1] == 0xD8 && tiff[i + 2] == 0xFF) {
      stderr.writeln('EXIF 안에 지우지 못한 JPEG 이 남아 있다 (TIFF 위치 $i)');
      exit(1);
    }
  }

  File(args[1]).writeAsBytesSync([0xFF, 0xD8, ...app1, 0xFF, 0xD9]);
  stdout.writeln('${args[1]}: ${app1.length + 4}바이트');
}
