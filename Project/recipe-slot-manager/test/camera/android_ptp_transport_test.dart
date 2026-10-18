import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/camera/android_ptp_transport.dart';
import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/ptp/ptp_container.dart';
import 'package:recipe_slot_manager/ptp/ptp_transport.dart';

/// 응답 컨테이너.
Uint8List response(int code, int transactionId) {
  final bytes = ByteData(ptpHeaderLength)
    ..setUint32(0, ptpHeaderLength, Endian.little)
    ..setUint16(4, ptpResponseType, Endian.little)
    ..setUint16(6, code, Endian.little)
    ..setUint32(8, transactionId, Endian.little);
  return bytes.buffer.asUint8List();
}

Uint8List join(List<Uint8List> parts) =>
    Uint8List.fromList([for (final part in parts) ...part]);

({int type, int code, int transactionId, List<int> params}) parse(
  Uint8List bytes,
) {
  final view = ByteData.sublistView(bytes);
  return (
    type: view.getUint16(4, Endian.little),
    code: view.getUint16(6, Endian.little),
    transactionId: view.getUint32(8, Endian.little),
    params: [
      for (var offset = 12; offset + 4 <= bytes.length; offset += 4)
        view.getUint32(offset, Endian.little),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('recipe_slot_manager/ptp');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// 카메라로 보낸 bulk OUT 전송.
  final written = <Uint8List>[];

  /// 다음 `read` 마다 하나씩 돌려줄 bulk IN 패킷.
  final packets = <Uint8List>[];
  final methods = <String>[];

  /// `read` 호출마다 받은 시간 제한 인자(ms).
  final readTimeouts = <Object?>[];
  Object? writeError;

  setUp(() {
    written.clear();
    packets.clear();
    methods.clear();
    readTimeouts.clear();
    writeError = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      switch (call.method) {
        case 'open':
          return {'name': 'X-T5'};
        case 'write':
          if (writeError case final error?) throw error;
          written.add(call.arguments as Uint8List);
          return null;
        case 'read':
          readTimeouts.add(call.arguments);
          return packets.removeAt(0);
        case 'close':
          return null;
      }
      throw MissingPluginException();
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  final getSlot = ptpCommand(
    PtpOp.getDevicePropValue,
    transactionId: 5,
    params: [FujiProp.presetSlot],
  );
  final slotValue = Uint8List.fromList([0x03, 0x00]);

  group('connect', () {
    test('장치를 열고 transaction ID 0, 세션 ID 1 로 세션을 연다', () async {
      packets.add(response(PtpResponse.ok, 0));

      expect(await AndroidPtpTransport().connect(), 'X-T5');

      final open = parse(written.single);
      expect(open.code, PtpOp.openSession);
      expect(open.transactionId, 0);
      expect(open.params, [1]);
    });

    test('세션이 이미 열려 있어도 연결로 본다', () async {
      packets.add(response(PtpResponse.sessionAlreadyOpen, 0));

      expect(await AndroidPtpTransport().connect(), 'X-T5');
    });

    test('세션을 열지 못하면 장치를 닫고 PtpTransportException 을 던진다', () async {
      packets.add(response(0x2002, 0));

      await expectLater(
        AndroidPtpTransport().connect(),
        throwsA(isA<PtpTransportException>()),
      );
      expect(methods.last, 'close');
    });

    test('세션을 여는 중 USB 오류가 나도 장치를 닫는다', () async {
      writeError = PlatformException(code: 'timeout', message: 'USB 응답 시간 초과');

      await expectLater(
        AndroidPtpTransport().connect(),
        throwsA(isA<PtpTransportException>()),
      );
      expect(methods.last, 'close');
    });
  });

  group('send', () {
    test('시간이 초과된 앞 명령의 늦은 응답은 건너뛰고 이 명령의 응답을 읽는다', () async {
      packets.addAll([
        response(PtpResponse.ok, 4),
        join([
          ptpDataContainer(getSlot, slotValue),
          response(PtpResponse.ok, 5),
        ]),
      ]);

      final reply = await AndroidPtpTransport().send(getSlot);

      expect(reply.data, slotValue);
    });

    test('데이터와 응답이 한 패킷으로 와도 값과 코드를 모두 읽는다', () async {
      packets.add(
        join([
          ptpDataContainer(getSlot, slotValue),
          response(PtpResponse.ok, 5),
        ]),
      );

      final reply = await AndroidPtpTransport().send(getSlot);

      expect(reply.code, PtpResponse.ok);
      expect(reply.data, slotValue);
      expect(written, [getSlot]);
    });

    test('컨테이너가 여러 패킷으로 쪼개져 와도 이어 붙여 읽는다', () async {
      final whole = join([
        ptpDataContainer(getSlot, slotValue),
        response(PtpResponse.ok, 5),
      ]);
      packets.addAll([
        whole.sublist(0, 5),
        whole.sublist(5, 13),
        Uint8List(0),
        whole.sublist(13),
      ]);

      final reply = await AndroidPtpTransport().send(getSlot);

      expect(reply.code, PtpResponse.ok);
      expect(reply.data, slotValue);
    });

    test('값을 쓰면 명령과 같은 코드·transaction ID 의 데이터 컨테이너를 이어 보낸다', () async {
      final setSlot = ptpCommand(
        PtpOp.setDevicePropValue,
        transactionId: 9,
        params: [FujiProp.presetSlot],
      );
      packets.add(response(PtpResponse.ok, 9));

      final reply = await AndroidPtpTransport().send(setSlot, data: slotValue);

      expect(reply.isOk, isTrue);
      expect(reply.data, isEmpty);
      expect(written.first, setSlot);
      final data = parse(written.last);
      expect(data.type, ptpDataType);
      expect(data.code, PtpOp.setDevicePropValue);
      expect(data.transactionId, 9);
      expect(written.last.sublist(ptpHeaderLength), slotValue);
    });

    test('동시에 보낸 명령도 앞 명령의 응답을 다 읽은 뒤에 다음 명령을 보낸다', () async {
      final transport = AndroidPtpTransport();
      final next = ptpCommand(
        PtpOp.getDevicePropValue,
        transactionId: 6,
        params: [FujiProp.presetName],
      );
      packets.addAll([
        response(PtpResponse.ok, 5),
        response(PtpResponse.ok, 6),
      ]);

      await Future.wait([transport.send(getSlot), transport.send(next)]);

      expect(methods, ['write', 'read', 'write', 'read']);
    });

    test('시간 제한을 주면 read 에 ms 로 싣고, 없으면 싣지 않는다', () async {
      packets.addAll([
        response(PtpResponse.ok, 5),
        response(PtpResponse.ok, 5),
      ]);
      final transport = AndroidPtpTransport();

      await transport.send(getSlot, timeout: const Duration(seconds: 60));
      await transport.send(getSlot);

      expect(readTimeouts, [60000, null]);
    });

    test('20 MB 데이터가 64 KiB 패킷 수백 개로 와도 빨리 모은다', () async {
      final payload = Uint8List(20 * 1024 * 1024)..[12345] = 7;
      final whole = join([
        ptpDataContainer(getSlot, payload),
        response(PtpResponse.ok, 5),
      ]);
      const packet = 64 * 1024;
      for (var at = 0; at < whole.length; at += packet) {
        packets.add(
          Uint8List.sublistView(
            whole,
            at,
            at + packet < whole.length ? at + packet : whole.length,
          ),
        );
      }
      final watch = Stopwatch()..start();

      final reply = await AndroidPtpTransport().send(getSlot);

      expect(reply.data.length, payload.length);
      expect(reply.data[12345], 7);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('데이터·응답이 아닌 컨테이너는 PtpTransportException 을 던진다', () async {
      final event = response(PtpResponse.ok, 5);
      ByteData.sublistView(event).setUint16(4, 4, Endian.little);
      packets.add(event);

      await expectLater(
        AndroidPtpTransport().send(getSlot),
        throwsA(isA<PtpTransportException>()),
      );
    });

    test('머리말보다 짧은 길이를 적은 컨테이너는 PtpTransportException 을 던진다', () async {
      final broken = response(PtpResponse.ok, 5);
      ByteData.sublistView(broken).setUint32(0, 4, Endian.little);
      packets.add(broken);

      await expectLater(
        AndroidPtpTransport().send(getSlot),
        throwsA(isA<PtpTransportException>()),
      );
    });

    test('빈 패킷만 이어지면 PtpTransportException 을 던진다', () async {
      packets.addAll([for (var i = 0; i < 10; i++) Uint8List(0)]);

      await expectLater(
        AndroidPtpTransport().send(getSlot),
        throwsA(isA<PtpTransportException>()),
      );
    });

    test('플랫폼 오류는 메시지 그대로 PtpTransportException 으로 바꾼다', () async {
      writeError = PlatformException(code: 'timeout', message: 'USB 응답 시간 초과');

      await expectLater(
        AndroidPtpTransport().send(getSlot),
        throwsA(
          isA<PtpTransportException>().having(
            (e) => e.message,
            'message',
            'USB 응답 시간 초과',
          ),
        ),
      );
    });
  });

  group('disconnect', () {
    test('마지막 명령 다음 transaction ID 로 세션을 닫고 장치를 닫는다', () async {
      final transport = AndroidPtpTransport();
      packets.addAll([
        join([
          ptpDataContainer(getSlot, slotValue),
          response(PtpResponse.ok, 5),
        ]),
        response(PtpResponse.ok, 6),
      ]);
      await transport.send(getSlot);

      await transport.disconnect();

      final close = parse(written.last);
      expect(close.code, PtpOp.closeSession);
      expect(close.transactionId, 6);
      expect(methods.last, 'close');
    });

    test('세션을 닫지 못해도 장치는 닫는다', () async {
      writeError = PlatformException(code: 'disconnected', message: '분리됨');

      await AndroidPtpTransport().disconnect();

      expect(methods.last, 'close');
    });
  });
}
