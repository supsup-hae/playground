import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/photo/locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Future<Object?> Function(MethodCall call) handler;
  const locator = PlatformLocator();

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(locationChannel, (call) {
      calls.add(call);
      return handler(call);
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(locationChannel, null));

  test('현재 위치와 오차 반경을 받는다', () async {
    handler = (_) async => {
      'latitude': 35.6587,
      'longitude': 139.7005,
      'accuracy': 12.5,
    };

    final fix = await locator.current();

    expect(calls.single.method, 'current');
    expect(fix.point, (latitude: 35.6587, longitude: 139.7005));
    expect(fix.accuracy, 12.5);
  });

  test('위치를 받지 못하면(null) unavailable', () async {
    handler = (_) async => null;

    await expectLater(
      locator.current(),
      throwsA(
        isA<LocateException>().having((e) => e.code, 'code', 'unavailable'),
      ),
    );
  });

  test('권한 없음·위치 꺼짐은 이유를 한국어로 전한다', () async {
    for (final (code, message) in [
      ('denied', '위치 권한이 없습니다'),
      ('disabled', '위치 서비스가 꺼져 있습니다'),
    ]) {
      handler = (_) async => throw PlatformException(code: code);

      await expectLater(
        locator.current(),
        throwsA(
          isA<LocateException>()
              .having((e) => e.code, 'code', code)
              .having((e) => e.message, 'message', message),
        ),
      );
    }
  });

  test('응답이 시간 안에 오지 않으면 timeout', () async {
    handler = (_) => Completer<Object?>().future;

    await expectLater(
      const PlatformLocator(timeout: Duration(milliseconds: 10)).current(),
      throwsA(isA<LocateException>().having((e) => e.code, 'code', 'timeout')),
    );
  });

  test('채널이 없으면 unavailable', () async {
    messenger.setMockMethodCallHandler(locationChannel, null);

    await expectLater(
      locator.current(),
      throwsA(
        isA<LocateException>().having((e) => e.code, 'code', 'unavailable'),
      ),
    );
    expect(await locator.requestAccess(), isFalse);
  });

  test('권한 요청 결과를 그대로 돌려준다', () async {
    handler = (_) async => true;

    expect(await locator.requestAccess(), isTrue);
    expect(calls.single.method, 'requestAccess');
  });
}
