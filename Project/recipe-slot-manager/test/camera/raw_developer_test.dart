import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/camera/fuji_camera.dart';
import 'package:recipe_slot_manager/camera/raw_developer.dart';
import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/ptp/ptp_string.dart';

import '../support/fake_ptp_transport.dart';

/// 매개변수 30개짜리 기준 프로필.
Uint8List baseProfile() {
  final bytes = Uint8List(625);
  ByteData.sublistView(bytes).setUint16(0, 30, Endian.little);
  return bytes;
}

void main() {
  late FakePtpTransport transport;
  late RawDeveloper developer;
  final raf = Uint8List(3 * 1024 * 1024)..[0] = 0x46;

  setUp(() {
    transport = FakePtpTransport(slots: {})..rawBaseProfile = baseProfile();
    developer = RawDeveloper(
      FujiCamera(transport, slotSwitchDelay: Duration.zero),
      pollInterval: Duration.zero,
      pollTimeout: const Duration(seconds: 1),
    );
  });

  group('loadRaf', () {
    test('ObjectInfo 와 RAF 를 보내고 기준 프로필을 읽는다', () async {
      await developer.loadRaf(raf);

      expect(transport.sent.map((c) => c.$1), [
        FujiOp.sendObjectInfo,
        FujiOp.sendObject2,
        PtpOp.getDevicePropValue,
      ]);
      expect(transport.sent.first.$2, [0, 0, 0]);
      expect(transport.raf, raf);
      expect(developer.rafLoaded, isTrue);
    });

    test('ObjectInfo 는 RAF 형식 0xF802, 크기, 파일 이름 FUP_FILE.dat 이다', () async {
      await developer.loadRaf(raf);

      final info = transport.rafObjectInfo!;
      final view = ByteData.sublistView(info);
      expect(view.getUint16(4, Endian.little), FujiOp.rafFormat);
      expect(view.getUint32(8, Endian.little), raf.length);
      final name = encodePtpString('FUP_FILE.dat');
      expect(info.sublist(52, 52 + name.length), name);
      expect(info.length, 52 + name.length + 3);
    });

    test('RAF 를 보낸 뒤에도 프로필이 비어 있으면 실패한다', () async {
      transport.rawBaseProfile = Uint8List(0);

      await expectLater(
        developer.loadRaf(raf),
        throwsA(isA<RawDevelopException>()),
      );
      expect(developer.rafLoaded, isFalse);
    });

    test('RAF 보내기가 거부되면 실패한다', () async {
      transport.rejectOps[FujiOp.sendObject2] = 0x2002;

      await expectLater(
        developer.loadRaf(raf),
        throwsA(
          isA<RawDevelopException>().having(
            (e) => e.message,
            'message',
            contains('RAF 보내기'),
          ),
        ),
      );
    });
  });

  group('develop', () {
    test('프로필 쓰기 → 현상 시작 → 결과 받기 → 결과 지우기 순서로 JPEG 을 돌려준다', () async {
      await developer.loadRaf(raf);
      transport.sent.clear();

      final jpeg = await developer.develop({'highlight': -1});

      expect(jpeg.sublist(0, 2), [0xFF, 0xD8]);
      expect(transport.sent.map((c) => c.$1), [
        PtpOp.setDevicePropValue,
        PtpOp.getObjectHandles,
        PtpOp.setDevicePropValue,
        PtpOp.getObjectHandles,
        PtpOp.getObjectInfo,
        PtpOp.getObject,
        PtpOp.deleteObject,
      ]);
      expect(transport.sent[0].$2, [FujiProp.rawProfile]);
      expect(transport.sent[1].$2, [0xFFFFFFFF, 0, 0]);
      expect(transport.sent[2].$2, [FujiProp.startRawConversion]);
      expect(transport.deletedHandles, [FakePtpTransport.resultHandle]);
      final written = ByteData.sublistView(transport.writtenProfiles.single);
      expect(written.getInt32(625 - 30 * 4 + 16 * 4, Endian.little), -10);
    });

    test('카메라에 이미 있던 객체(메모리 카드 사진)는 받지도 지우지도 않는다', () async {
      transport.existingHandles.addAll([0x10, 0x11]);
      await developer.loadRaf(raf);

      final jpeg = await developer.develop({'highlight': 1});

      expect(jpeg[2], isNot(0x01), reason: '카드 사진이 아니라 현상 결과');
      expect(transport.fetchedHandles, [FakePtpTransport.resultHandle]);
      expect(transport.deletedHandles, [FakePtpTransport.resultHandle]);
    });

    test('새로 생긴 객체라도 JPEG 이 아니면 결과로 받지 않는다', () async {
      transport.newObjects[0x30] = FujiOp.rafFormat;
      await developer.loadRaf(raf);

      await developer.develop({'highlight': 1});

      expect(transport.fetchedHandles, [FakePtpTransport.resultHandle]);
      expect(transport.deletedHandles, [FakePtpTransport.resultHandle]);
    });

    test('결과를 받은 뒤 지우기가 실패해도 결과를 돌려주고 로그에 남긴다', () async {
      await developer.loadRaf(raf);
      transport.throwOps.add(PtpOp.deleteObject);

      final jpeg = await developer.develop({'highlight': 1});

      expect(jpeg.sublist(0, 2), [0xFF, 0xD8]);
      expect(
        developer.camera.log.entries.map((e) => e.$2),
        contains(startsWith('현상 결과를 카메라에서 지우지 못했다')),
      );
    });

    test('앞 현상이 늦게 남긴 결과는 다음 현상의 결과로 쓰지 않는다', () async {
      await developer.loadRaf(raf);
      await developer.develop({'highlight': 1});
      // 앞 결과가 지워지지 않고 남은 경우 (예: 시간 초과 뒤 늦게 생김).
      transport.existingHandles.add(FakePtpTransport.resultHandle);
      transport.fetchedHandles.clear();

      await developer.develop({'highlight': 2});

      expect(transport.fetchedHandles, [FakePtpTransport.resultHandle + 1]);
    });

    test('다시 연결하면 RAF 를 다시 보내야 한다', () async {
      await developer.loadRaf(raf);

      await developer.camera.connect();

      expect(developer.rafLoaded, isFalse);
      expect(developer.rafName, isNull);
      await expectLater(
        developer.develop({'highlight': 1}),
        throwsA(isA<RawDevelopException>()),
      );
    });

    test('결과가 늦게 생겨도 기다렸다가 받는다', () async {
      await developer.loadRaf(raf);
      transport.conversionPolls = 2;
      transport.sent.clear();

      await developer.develop({'highlight': 1});

      expect(
        transport.sent.where((c) => c.$1 == PtpOp.getObjectHandles),
        hasLength(4),
        reason: '시작 전 목록 1번 + 기다리며 3번',
      );
    });

    test('기다리는 시간 안에 결과가 없으면 실패한다', () async {
      developer = RawDeveloper(
        FujiCamera(transport, slotSwitchDelay: Duration.zero),
        pollInterval: Duration.zero,
        pollTimeout: Duration.zero,
      );
      await developer.loadRaf(raf);
      transport.conversionPolls = 99;

      await expectLater(
        developer.develop({'highlight': 1}),
        throwsA(isA<RawDevelopException>()),
      );
    });

    test('RAF 를 보내기 전에는 현상할 수 없다', () async {
      await expectLater(
        developer.develop({'highlight': 1}),
        throwsA(isA<RawDevelopException>()),
      );
      expect(transport.sent, isEmpty);
    });

    test('결과가 JPEG 이 아니면 실패한다', () async {
      transport.developResult = (_) => Uint8List.fromList([1, 2, 3]);
      await developer.loadRaf(raf);

      await expectLater(
        developer.develop({'highlight': 1}),
        throwsA(isA<RawDevelopException>()),
      );
    });

    test('현상 시작이 거부되면 실패한다', () async {
      await developer.loadRaf(raf);
      transport.rejectSet[FujiProp.startRawConversion] = 0x201D;

      await expectLater(
        developer.develop({'highlight': 1}),
        throwsA(isA<RawDevelopException>()),
      );
    });
  });
}
