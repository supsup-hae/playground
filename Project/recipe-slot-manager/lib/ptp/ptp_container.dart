import 'dart:typed_data';

/// 컨테이너 머리말 길이: `[u32 길이][u16 타입][u16 코드][u32 transaction ID]`.
const ptpHeaderLength = 12;
const _commandType = 1;

/// 명령과 함께 오가는 값 바이트를 담는 컨테이너 타입.
const ptpDataType = 2;

/// 명령의 결과 코드를 담는 컨테이너 타입.
const ptpResponseType = 3;

/// PTP 명령 컨테이너를 만든다.
///
/// `[u32 길이][u16 타입][u16 코드][u32 transaction ID][u32 매개변수 × n]`,
/// 모두 리틀 엔디언이다.
Uint8List ptpCommand(
  int code, {
  required int transactionId,
  List<int> params = const [],
}) {
  final length = ptpHeaderLength + 4 * params.length;
  final bytes = ByteData(length)
    ..setUint32(0, length, Endian.little)
    ..setUint16(4, _commandType, Endian.little)
    ..setUint16(6, code, Endian.little)
    ..setUint32(8, transactionId, Endian.little);
  for (var i = 0; i < params.length; i++) {
    bytes.setUint32(ptpHeaderLength + 4 * i, params[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// [command] 와 같은 코드·transaction ID 로 [payload] 를 담은 데이터 컨테이너를 만든다.
Uint8List ptpDataContainer(Uint8List command, Uint8List payload) {
  final length = ptpHeaderLength + payload.length;
  final bytes = Uint8List(length)
    ..setRange(6, ptpHeaderLength, command, 6)
    ..setRange(ptpHeaderLength, length, payload);
  ByteData.sublistView(bytes)
    ..setUint32(0, length, Endian.little)
    ..setUint16(4, ptpDataType, Endian.little);
  return bytes;
}

/// 컨테이너 머리말에서 전체 길이, 타입, 코드, transaction ID 를 읽는다.
({int length, int type, int code, int transactionId}) ptpContainerHeader(
  Uint8List bytes,
) {
  if (bytes.length < ptpHeaderLength) {
    throw FormatException('PTP 컨테이너 ${bytes.length}바이트: 머리말보다 짧음');
  }
  final view = ByteData.sublistView(bytes);
  return (
    length: view.getUint32(0, Endian.little),
    type: view.getUint16(4, Endian.little),
    code: view.getUint16(6, Endian.little),
    transactionId: view.getUint32(8, Endian.little),
  );
}

/// PTP 응답 컨테이너에서 응답 코드를 읽는다.
int ptpResponseCode(Uint8List response) {
  final header = ptpContainerHeader(response);
  if (header.type != ptpResponseType) {
    throw FormatException('PTP 응답 컨테이너 아님 (타입 ${header.type})');
  }
  return header.code;
}
