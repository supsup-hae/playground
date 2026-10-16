import 'package:flutter/services.dart';
import 'package:recipe_slot_manager/ptp/ptp_container.dart';
import 'package:recipe_slot_manager/ptp/ptp_transport.dart';

/// macOS `ImageCaptureCore` 로 PTP 명령을 보낸다. Swift 쪽은 `macos/Runner/PtpChannel.swift`.
class MacosPtpTransport implements PtpTransport {
  static const _channel = MethodChannel('recipe_slot_manager/ptp');

  @override
  Future<String> connect() => _invoke(
    () async => await _channel.invokeMethod<String>('connect') ?? 'Fujifilm',
  );

  @override
  Future<PtpReply> send(Uint8List command, {Uint8List? data}) =>
      _invoke(() async {
        final reply = await _channel.invokeMapMethod<String, Object?>('send', {
          'command': command,
          'data': data,
        });
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
      _invoke(() => _channel.invokeMethod<void>('disconnect'));

  Future<T> _invoke<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw PtpTransportException(e.message ?? e.code);
    } on MissingPluginException {
      throw const PtpTransportException('이 플랫폼에는 카메라 연결 기능이 없다');
    } on FormatException catch (e) {
      throw PtpTransportException(e.message);
    }
  }
}
