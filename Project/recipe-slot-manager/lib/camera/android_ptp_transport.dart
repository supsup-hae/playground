import 'dart:typed_data';

import 'package:recipe_slot_manager/camera/ptp_channel.dart';
import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/ptp/ptp_container.dart';
import 'package:recipe_slot_manager/ptp/ptp_transport.dart';

/// Android USB bulk 전송 위에서 PTP 를 주고받는다. Kotlin 쪽은
/// `android/app/src/main/kotlin/dev/supsuphae/recipe_slot_manager/PtpChannel.kt` 이고,
/// 바이트를 그대로 옮기기만 한다. 세션 열기와 컨테이너 조립·해석은 여기서 한다.
class AndroidPtpTransport implements PtpTransport {
  static const _sessionId = 1;

  /// 빈 패킷이 이만큼 이어지면 카메라가 응답하지 않는 것으로 본다.
  static const _maxEmptyReads = 3;

  /// 마지막으로 보낸 명령의 transaction ID. 세션을 닫는 명령이 그다음 번호를 쓴다.
  var _lastTransactionId = 0;

  @override
  Future<String> connect() async {
    final opened = await guardPtpChannel(
      () => ptpChannel.invokeMapMethod<String, Object?>('open'),
    );
    _lastTransactionId = 0;
    try {
      final reply = await guardPtpChannel(
        () => _transact(
          ptpCommand(PtpOp.openSession, transactionId: 0, params: [_sessionId]),
        ),
      );
      if (!reply.isOk && reply.code != PtpResponse.sessionAlreadyOpen) {
        throw PtpTransportException(
          '세션을 열지 못했다 (응답 0x${reply.code.toRadixString(16)})',
        );
      }
    } on PtpTransportException {
      // 열어 둔 장치를 남기면 다음 연결이 USB 인터페이스를 잡지 못한다.
      await guardPtpChannel(() => ptpChannel.invokeMethod<void>('close'));
      rethrow;
    }
    return switch (opened) {
      {'name': final String name} => name,
      _ => 'Fujifilm',
    };
  }

  @override
  Future<PtpReply> send(Uint8List command, {Uint8List? data}) =>
      guardPtpChannel(() {
        _lastTransactionId = ByteData.sublistView(command)
            .getUint32(8, Endian.little);
        return _transact(command, data: data);
      });

  @override
  Future<void> disconnect() async {
    try {
      await guardPtpChannel(
        () => _transact(
          ptpCommand(PtpOp.closeSession, transactionId: ++_lastTransactionId),
        ),
      );
    } on PtpTransportException {
      // 케이블이 빠졌거나 세션이 이미 없다. 장치는 아래에서 그대로 닫는다.
    }
    await guardPtpChannel(() => ptpChannel.invokeMethod<void>('close'));
  }

  Future<PtpReply> _transact(Uint8List command, {Uint8List? data}) async {
    await ptpChannel.invokeMethod<void>('write', command);
    if (data != null) {
      await ptpChannel.invokeMethod<void>(
        'write',
        ptpDataContainer(command, data),
      );
    }
    return _readReply(
      ByteData.sublistView(command).getUint32(8, Endian.little),
    );
  }

  /// [transactionId] 의 응답 컨테이너가 올 때까지 bulk IN 을 읽는다. 한 패킷에 컨테이너
  /// 여럿이 오거나 컨테이너 하나가 여러 패킷으로 쪼개져 와도 머리말의 길이로 나눈다.
  /// 시간이 초과된 앞 명령의 늦은 데이터·응답은 transaction ID 가 달라 건너뛴다.
  Future<PtpReply> _readReply(int transactionId) async {
    final payload = BytesBuilder(copy: false);
    var pending = Uint8List(0);
    var emptyReads = 0;
    while (true) {
      while (pending.length >= ptpHeaderLength) {
        final header = ptpContainerHeader(pending);
        if (header.length < ptpHeaderLength) {
          throw FormatException('PTP 컨테이너 길이 ${header.length} 가 머리말보다 짧다');
        }
        if (pending.length < header.length) break;
        final body = pending.sublist(ptpHeaderLength, header.length);
        pending = pending.sublist(header.length);
        if (header.transactionId != transactionId) continue;
        switch (header.type) {
          case ptpDataType:
            payload.add(body);
          case ptpResponseType:
            return PtpReply(header.code, payload.takeBytes());
          default:
            throw FormatException('PTP 데이터·응답 컨테이너가 아니다 (타입 ${header.type})');
        }
      }
      final packet =
          await ptpChannel.invokeMethod<Uint8List>('read') ?? Uint8List(0);
      if (packet.isEmpty) {
        if (++emptyReads >= _maxEmptyReads) {
          throw const PtpTransportException('카메라가 응답 컨테이너를 보내지 않았다');
        }
        continue;
      }
      emptyReads = 0;
      pending = Uint8List.fromList([...pending, ...packet]);
    }
  }
}
