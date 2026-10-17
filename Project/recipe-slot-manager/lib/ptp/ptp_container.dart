import 'dart:typed_data';

const _headerLength = 12;
const _commandType = 1;
const _responseType = 3;

/// PTP 명령 컨테이너를 만든다.
///
/// `[u32 길이][u16 타입][u16 코드][u32 transaction ID][u32 매개변수 × n]`,
/// 모두 리틀 엔디언이다.
Uint8List ptpCommand(
  int code, {
  required int transactionId,
  List<int> params = const [],
}) {
  final length = _headerLength + 4 * params.length;
  final bytes = ByteData(length)
    ..setUint32(0, length, Endian.little)
    ..setUint16(4, _commandType, Endian.little)
    ..setUint16(6, code, Endian.little)
    ..setUint32(8, transactionId, Endian.little);
  for (var i = 0; i < params.length; i++) {
    bytes.setUint32(_headerLength + 4 * i, params[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// PTP 응답 컨테이너에서 응답 코드를 읽는다.
int ptpResponseCode(Uint8List response) {
  if (response.length < _headerLength) {
    throw FormatException('PTP 응답이 ${response.length}바이트로 머리말보다 짧다');
  }
  final bytes = ByteData.sublistView(response);
  final type = bytes.getUint16(4, Endian.little);
  if (type != _responseType) {
    throw FormatException('PTP 응답 컨테이너가 아니다 (타입 $type)');
  }
  return bytes.getUint16(6, Endian.little);
}
