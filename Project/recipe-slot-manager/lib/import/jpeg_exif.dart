import 'dart:typed_data';

import 'package:recipe_slot_manager/import/recipe_import.dart';

/// IFD 항목 하나. [offset] 은 값 바이트의 위치다 (4바이트 이하면 항목 안의 값 자리).
typedef IfdEntry = ({int type, int count, int offset});

const _typeSizes = {1: 1, 2: 1, 3: 2, 4: 4, 6: 1, 7: 1, 8: 2, 9: 4};

const _broken = ImportException('파일이 잘렸거나 EXIF 정보가 깨졌다');

/// [view] 의 [ifdAt] 에 있는 IFD 를 읽는다. 값 위치는 [base] 를 더한 [view] 안의 위치다.
Map<int, IfdEntry> readIfd(
  ByteData view,
  int ifdAt,
  Endian endian, {
  int base = 0,
}) {
  if (ifdAt < 0 || ifdAt + 2 > view.lengthInBytes) throw _broken;
  final count = view.getUint16(ifdAt, endian);
  if (ifdAt + 2 + 12 * count > view.lengthInBytes) throw _broken;
  final entries = <int, IfdEntry>{};
  for (var i = 0; i < count; i++) {
    final at = ifdAt + 2 + 12 * i;
    final type = view.getUint16(at + 2, endian);
    final valueCount = view.getUint32(at + 4, endian);
    final size = (_typeSizes[type] ?? 1) * valueCount;
    final offset = size <= 4 ? at + 8 : base + view.getUint32(at + 8, endian);
    if (offset + size > view.lengthInBytes) throw _broken;
    entries[view.getUint16(at, endian)] = (
      type: type,
      count: valueCount,
      offset: offset,
    );
  }
  return entries;
}

/// [entry] 의 값을 형식(부호 있음·없음, 8·16·32비트)에 맞게 읽는다.
List<int> ifdValues(ByteData view, IfdEntry entry, Endian endian) => [
  for (var i = 0; i < entry.count; i++)
    switch (entry.type) {
      3 => view.getUint16(entry.offset + 2 * i, endian),
      8 => view.getInt16(entry.offset + 2 * i, endian),
      4 => view.getUint32(entry.offset + 4 * i, endian),
      9 => view.getInt32(entry.offset + 4 * i, endian),
      6 => view.getInt8(entry.offset + i),
      _ => view.getUint8(entry.offset + i),
    },
];

/// JPEG 앞부분에서 APP1 Exif 를 찾아 MakerNote(0x927C) 바이트를 꺼낸다.
/// APP1 은 파일 앞 64 KiB 안에 있으므로 파일 전체가 필요하지 않다.
Uint8List readMakerNote(Uint8List jpeg) {
  if (jpeg.length < 4 || jpeg[0] != 0xFF || jpeg[1] != 0xD8) {
    throw const ImportException('JPEG 파일이 아니다');
  }
  var at = 2;
  while (at + 4 <= jpeg.length && jpeg[at] == 0xFF) {
    final marker = jpeg[at + 1];
    if (marker == 0xDA || marker == 0xD9) break;
    // 세그먼트 길이는 길이 필드 2바이트를 포함하므로 2 이상이다.
    final length = jpeg[at + 2] << 8 | jpeg[at + 3];
    final end = at + 2 + length;
    if (length < 2 || end > jpeg.length) throw _broken;
    final body = Uint8List.sublistView(jpeg, at + 4, end);
    if (marker == 0xE1 && _isExif(body)) {
      return _makerNoteIn(Uint8List.sublistView(body, 6));
    }
    at = end;
  }
  throw const ImportException('사진에 EXIF 정보가 없다');
}

bool _isExif(Uint8List body) =>
    body.length >= 6 &&
    String.fromCharCodes(body.sublist(0, 4)) == 'Exif' &&
    body[4] == 0 &&
    body[5] == 0;

Uint8List _makerNoteIn(Uint8List tiff) {
  if (tiff.length < 8) throw _broken;
  final view = ByteData.sublistView(tiff);
  final endian = switch (String.fromCharCodes(tiff.sublist(0, 2))) {
    'II' => Endian.little,
    'MM' => Endian.big,
    _ => throw _broken,
  };
  final ifd0 = readIfd(view, view.getUint32(4, endian), endian);
  final exifPointer = ifd0[0x8769];
  if (exifPointer == null) throw const ImportException('사진에 EXIF 정보가 없다');
  if (exifPointer.count != 1) throw _broken;
  final exif = readIfd(
    view,
    ifdValues(view, exifPointer, endian).first,
    endian,
  );
  final makerNote = exif[0x927C];
  if (makerNote == null) {
    throw const ImportException('사진에 제조사 정보(MakerNote)가 없다');
  }
  return Uint8List.sublistView(
    tiff,
    makerNote.offset,
    makerNote.offset + makerNote.count,
  );
}
