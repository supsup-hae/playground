import 'dart:typed_data';

/// 글자 수 바이트(u8)에 널까지 들어가야 하므로 254글자가 한도다.
const maxPtpStringLength = 254;

/// PTP 문자열: `[u8 글자 수(널 포함)][UTF-16LE 글자…][u16 0]`.
/// 빈 문자열은 0 한 바이트다.
Uint8List encodePtpString(String value) {
  if (value.isEmpty) return Uint8List.fromList([0]);
  final units = value.codeUnits;
  if (units.length > maxPtpStringLength) {
    throw ArgumentError.value(
      value,
      'value',
      'PTP 문자열은 $maxPtpStringLength글자까지다',
    );
  }
  final bytes = ByteData(1 + 2 * (units.length + 1))
    ..setUint8(0, units.length + 1);
  for (var i = 0; i < units.length; i++) {
    bytes.setUint16(1 + 2 * i, units[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}

String decodePtpString(Uint8List bytes) {
  if (bytes.isEmpty || bytes[0] == 0) return '';
  final count = bytes[0];
  if (bytes.length < 1 + 2 * count) {
    throw FormatException('PTP 문자열 글자 수 $count 가 ${bytes.length}바이트를 넘는다');
  }
  final data = ByteData.sublistView(bytes);
  return String.fromCharCodes([
    for (var i = 0; i < count - 1; i++)
      data.getUint16(1 + 2 * i, Endian.little),
  ]);
}
