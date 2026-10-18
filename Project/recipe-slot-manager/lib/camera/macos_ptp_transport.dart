import 'dart:typed_data';

import 'package:recipe_slot_manager/camera/ptp_channel.dart';
import 'package:recipe_slot_manager/ptp/ptp_container.dart';
import 'package:recipe_slot_manager/ptp/ptp_transport.dart';

/// macOS `ImageCaptureCore` 로 PTP 명령을 보낸다. Swift 쪽은 `macos/Runner/PtpChannel.swift`.
class MacosPtpTransport implements PtpTransport {
  @override
  Future<String> connect() => guardPtpChannel(
    () async => await ptpChannel.invokeMethod<String>('connect') ?? 'Fujifilm',
  );

  @override
  Future<PtpReply> send(Uint8List command, {Uint8List? data}) =>
      guardPtpChannel(() async {
        final reply = await ptpChannel.invokeMapMethod<String, Object?>(
          'send',
          {'command': command, 'data': data},
        );
        if (reply case {'response': final Uint8List response}) {
          final data = reply['data'];
          return PtpReply(
            ptpResponseCode(response),
            data is Uint8List ? data : Uint8List(0),
          );
        }
        throw const PtpTransportException('PTP 응답이 비어 있다');
      });

  @override
  Future<void> disconnect() =>
      guardPtpChannel(() => ptpChannel.invokeMethod<void>('disconnect'));
}
