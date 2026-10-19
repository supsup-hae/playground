import 'dart:typed_data';

/// TIFF 값 형식.
const tiffByte = 1;
const tiffAscii = 2;
const tiffShort = 3;
const tiffLong = 4;
const tiffRational = 5;
const tiffUndefined = 7;
const tiffSByte = 6;
const tiffSLong = 9;

/// 값 하나를 이루는 정수의 크기. RATIONAL 은 u32 두 개(분자, 분모)가 값 하나다.
const _sizes = {
  tiffByte: 1,
  tiffAscii: 1,
  tiffShort: 2,
  tiffLong: 4,
  tiffRational: 4,
  tiffUndefined: 1,
  tiffSByte: 1,
  tiffSLong: 4,
};

/// ASCII 값: 글자 코드 뒤에 NUL.
List<int> asciiValue(String text) => [...text.codeUnits, 0];

/// IFD 하나와 그 뒤의 값 영역을 만든다. [base] 는 이 IFD 가 놓일 위치(값 위치 계산 기준).
/// RATIONAL 값은 `[분자, 분모, ...]` 로 받는다.
Uint8List _ifd(Map<int, (int, List<int>)> entries, int base, Endian endian) {
  final sorted = entries.keys.toList()..sort();
  final headerLength = 2 + 12 * sorted.length + 4;
  final data = BytesBuilder();
  final header = ByteData(headerLength)..setUint16(0, sorted.length, endian);
  for (var i = 0; i < sorted.length; i++) {
    final tag = sorted[i];
    final (type, values) = entries[tag]!;
    final size = _sizes[type]!;
    final count = type == tiffRational ? values.length ~/ 2 : values.length;
    final bytes = ByteData(size * values.length);
    for (var v = 0; v < values.length; v++) {
      switch (size) {
        case 1:
          bytes.setUint8(v, values[v] & 0xFF);
        case 2:
          bytes.setUint16(v * 2, values[v] & 0xFFFF, endian);
        default:
          bytes.setUint32(v * 4, values[v] & 0xFFFFFFFF, endian);
      }
    }
    final entry = 2 + 12 * i;
    header
      ..setUint16(entry, tag, endian)
      ..setUint16(entry + 2, type, endian)
      ..setUint32(entry + 4, count, endian);
    final raw = bytes.buffer.asUint8List();
    if (raw.length <= 4) {
      for (var b = 0; b < raw.length; b++) {
        header.setUint8(entry + 8 + b, raw[b]);
      }
    } else {
      header.setUint32(entry + 8, base + headerLength + data.length, endian);
      data.add(raw);
    }
  }
  return Uint8List.fromList([
    ...header.buffer.asUint8List(),
    ...data.toBytes(),
  ]);
}

/// 후지 MakerNote: `FUJIFILM` + IFD 위치 12 + 리틀 엔디언 IFD. 값 위치는 MakerNote 시작 기준.
Uint8List fujiMakerNote(Map<int, (int, List<int>)> tags) {
  final header = ByteData(12)..setUint32(8, 12, Endian.little);
  final bytes = header.buffer.asUint8List()..setAll(0, 'FUJIFILM'.codeUnits);
  return Uint8List.fromList([...bytes, ..._ifd(tags, 12, Endian.little)]);
}

/// SOI + APP1(Exif) + EOI 로 된 최소 JPEG. [makerNote] 가 null 이면 Exif IFD 에 MakerNote 를 넣지 않는다.
/// [ifd0Tags]·[exifTags] 는 각 IFD 에 더할 태그, [gpsTags] 가 있으면 GPS IFD 를 만든다.
/// [brokenExifPointer] 면 Exif IFD 위치 태그에 값을 두 개 넣는다(깨진 파일).
Uint8List jpegWithExif({
  Uint8List? makerNote,
  Map<int, (int, List<int>)> ifd0Tags = const {},
  Map<int, (int, List<int>)> exifTags = const {},
  Map<int, (int, List<int>)>? gpsTags,
  bool bigEndian = false,
  bool brokenExifPointer = false,
}) {
  final endian = bigEndian ? Endian.big : Endian.little;
  const ifd0At = 8;
  final exif = {
    ...exifTags,
    if (makerNote != null) 0x927C: (tiffUndefined, makerNote),
  };
  Map<int, (int, List<int>)> ifd0Entries(int exifAt, int gpsAt) => {
    ...ifd0Tags,
    0x8769: (tiffLong, [exifAt, if (brokenExifPointer) 0]),
    if (gpsTags != null) 0x8825: (tiffLong, [gpsAt]),
  };
  // 값 영역 길이는 위치와 무관하므로 한 번 만들어 길이를 잰 뒤 실제 위치로 다시 만든다.
  final exifAt = ifd0At + _ifd(ifd0Entries(0, 0), ifd0At, endian).length;
  final gpsAt = exifAt + _ifd(exif, exifAt, endian).length;
  final tiffHeader = ByteData(8)
    ..setUint8(0, bigEndian ? 0x4D : 0x49)
    ..setUint8(1, bigEndian ? 0x4D : 0x49)
    ..setUint16(2, 42, endian)
    ..setUint32(4, ifd0At, endian);
  final tiff = [
    ...tiffHeader.buffer.asUint8List(),
    ..._ifd(ifd0Entries(exifAt, gpsAt), ifd0At, endian),
    ..._ifd(exif, exifAt, endian),
    if (gpsTags != null) ..._ifd(gpsTags, gpsAt, endian),
  ];
  final app1 = [...'Exif'.codeUnits, 0, 0, ...tiff];
  final length = app1.length + 2;
  return Uint8List.fromList([
    0xFF, 0xD8, //
    0xFF, 0xE1, length >> 8, length & 0xFF, ...app1,
    0xFF, 0xD9,
  ]);
}
