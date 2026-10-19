import 'dart:typed_data';

import 'package:recipe_slot_manager/camera/ptp_channel.dart';
import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/ptp/ptp_container.dart';
import 'package:recipe_slot_manager/ptp/ptp_transport.dart';
import 'package:recipe_slot_manager/util/serial_queue.dart';

/// Android USB bulk 전송 위에서 PTP 를 주고받는다. Kotlin 쪽은
/// `android/app/src/main/kotlin/dev/supsuphae/recipe_slot_manager/PtpChannel.kt` 이고,
/// 바이트를 그대로 옮기기만 한다. 세션 열기와 컨테이너 조립·해석은 여기서 한다.
class AndroidPtpTransport implements PtpTransport {
  static const _sessionId = 1;

  /// 빈 패킷이 이만큼 이어지면 카메라가 응답하지 않는 것으로 본다.
  static const _maxEmptyReads = 3;

  /// 마지막으로 보낸 명령의 transaction ID. 세션을 닫는 명령이 그다음 번호를 쓴다.
  var _lastTransactionId = 0;

  /// bulk OUT·IN 이 명령 사이에 섞이면 응답이 다른 명령에 붙으므로, 호출하는 쪽이
  /// 겹쳐 불러도 연결·명령·끊기를 하나씩 한다.
  final _calls = SerialQueue();

  @override
  Future<String> connect() => _calls.run(() async {
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
          '세션 열기 실패 (응답 0x${reply.code.toRadixString(16)})',
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
  });

  @override
  Future<PtpReply> send(
    Uint8List command, {
    Uint8List? data,
    Duration? timeout,
  }) => _calls.run(
    () => guardPtpChannel(() {
      _lastTransactionId = ByteData.sublistView(command)
          .getUint32(8, Endian.little);
      return _transact(command, data: data, timeout: timeout);
    }),
  );

  @override
  Future<void> disconnect() => _calls.run(() async {
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
  });

  Future<PtpReply> _transact(
    Uint8List command, {
    Uint8List? data,
    Duration? timeout,
  }) async {
    await ptpChannel.invokeMethod<void>('write', command);
    if (data != null) {
      await ptpChannel.invokeMethod<void>(
        'write',
        ptpDataContainer(command, data),
      );
    }
    return _readReply(
      ByteData.sublistView(command).getUint32(8, Endian.little),
      timeout,
    );
  }

  /// [transactionId] 의 응답 컨테이너가 올 때까지 bulk IN 을 읽는다. 한 패킷에 컨테이너
  /// 여럿이 오거나 컨테이너 하나가 여러 패킷으로 쪼개져 와도 머리말의 길이로 나눈다.
  /// 시간이 초과된 앞 명령의 늦은 데이터·응답은 transaction ID 가 달라 건너뛴다.
  Future<PtpReply> _readReply(int transactionId, Duration? timeout) async {
    final payload = BytesBuilder(copy: false);
    // 아직 해석하지 않은 바이트. 컨테이너 하나를 다 받을 때까지는 이어 붙이지 않는다.
    final unread = BytesBuilder(copy: false);
    var needed = ptpHeaderLength;
    var emptyReads = 0;
    while (true) {
      while (unread.length >= needed) {
        final bytes = unread.takeBytes();
        final header = ptpContainerHeader(bytes);
        if (header.length < ptpHeaderLength) {
          throw FormatException('PTP 컨테이너 길이 ${header.length}: 머리말보다 짧음');
        }
        if (bytes.length < header.length) {
          unread.add(bytes);
          needed = header.length;
          break;
        }
        unread.add(Uint8List.sublistView(bytes, header.length));
        needed = ptpHeaderLength;
        if (header.transactionId != transactionId) continue;
        switch (header.type) {
          case ptpDataType:
            payload.add(
              Uint8List.sublistView(bytes, ptpHeaderLength, header.length),
            );
          case ptpResponseType:
            return PtpReply(header.code, payload.takeBytes());
          default:
            throw FormatException('PTP 데이터·응답 컨테이너 아님 (타입 ${header.type})');
        }
      }
      final packet =
          await ptpChannel.invokeMethod<Uint8List>(
            'read',
            timeout?.inMilliseconds,
          ) ??
          Uint8List(0);
      if (packet.isEmpty) {
        if (++emptyReads >= _maxEmptyReads) {
          throw const PtpTransportException('응답 컨테이너 없음');
        }
        continue;
      }
      emptyReads = 0;
      unread.add(packet);
    }
  }
}
