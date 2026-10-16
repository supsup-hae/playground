import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/camera/macos_ptp_transport.dart';
import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/ptp/ptp_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('recipe_slot_manager/ptp');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late Future<Object?> Function(MethodCall call) handler;

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('send 는 응답 컨테이너에서 코드를 읽고 데이터를 그대로 돌려준다', () async {
    handler = (_) async => {
      'response': Uint8List.fromList([
        12,
        0,
        0,
        0,
        3,
        0,
        0x01,
        0x20,
        1,
        0,
        0,
        0,
      ]),
      'data': Uint8List.fromList([0x11, 0x00]),
    };
    final command = Uint8List.fromList([1, 2, 3]);
    final value = Uint8List.fromList([7, 0]);

    final reply = await MacosPtpTransport().send(command, data: value);

    expect(reply.code, PtpResponse.ok);
    expect(reply.data, [0x11, 0x00]);
    expect(calls.single.arguments, {'command': command, 'data': value});
  });

  test('플랫폼 오류는 PtpTransportException 으로 바꾼다', () async {
    handler = (_) async =>
        throw PlatformException(code: 'timeout', message: 'PTP 응답 시간 초과');

    expect(
      () => MacosPtpTransport().send(Uint8List(12)),
      throwsA(
        isA<PtpTransportException>().having(
          (e) => e.message,
          'message',
          'PTP 응답 시간 초과',
        ),
      ),
    );
  });

  test('응답 컨테이너가 아니거나 비어 있으면 PtpTransportException 을 던진다', () async {
    handler = (_) async => {
      'response': Uint8List.fromList([
        12,
        0,
        0,
        0,
        2,
        0,
        0x01,
        0x20,
        1,
        0,
        0,
        0,
      ]),
      'data': Uint8List(0),
    };
    expect(
      () => MacosPtpTransport().send(Uint8List(12)),
      throwsA(isA<PtpTransportException>()),
    );

    handler = (_) async => {'data': Uint8List(0)};
    expect(
      () => MacosPtpTransport().send(Uint8List(12)),
      throwsA(isA<PtpTransportException>()),
    );
  });

  test('connect 는 모델 이름을 돌려준다', () async {
    handler = (_) async => 'X-T5';

    expect(await MacosPtpTransport().connect(), 'X-T5');
  });
}
