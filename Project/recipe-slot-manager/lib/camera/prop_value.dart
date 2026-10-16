import 'dart:typed_data';

/// 슬롯 속성 값 바이트와 정수 사이의 변환. 2바이트는 int16, 4바이트는 int32로 다루고,
/// 그 밖의 길이는 정수로 해석하지 않는다.
int? decodePropValue(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return switch (bytes.length) {
    2 => data.getInt16(0, Endian.little),
    4 => data.getInt32(0, Endian.little),
    _ => null,
  };
}

/// [value] 가 [length] 바이트에 들어가지 않으면 null. 부호 있는 값과 없는 값을 모두 받는다.
Uint8List? encodePropValue(int value, int length) {
  final data = ByteData(length);
  switch (length) {
    case 2 when value >= -0x8000 && value <= 0xFFFF:
      data.setUint16(0, value & 0xFFFF, Endian.little);
    case 4 when value >= -0x80000000 && value <= 0xFFFFFFFF:
      data.setUint32(0, value & 0xFFFFFFFF, Endian.little);
    default:
      return null;
  }
  return data.buffer.asUint8List();
}

/// `f6ff (-10)` 처럼 16진수와 정수를 함께 보여 준다. 값이 없으면 `-`.
String displayPropValue(Uint8List? bytes) {
  if (bytes == null) return '-';
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final number = decodePropValue(bytes);
  return number == null ? hex : '$hex ($number)';
}
