import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/photo/geocoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Future<Object?> Function(MethodCall call) handler;
  const geocoder = PlatformGeocoder();

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(geocoderChannel, (call) {
      calls.add(call);
      return handler(call);
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(geocoderChannel, null));

  test('좌표를 보내고 주소 칸을 받는다', () async {
    handler = (_) async => {
      'country': '일본',
      'admin': '도쿄도',
      'locality': '시부야구',
      'subLocality': '진난',
      'thoroughfare': null,
    };

    final place = await geocoder.reverse((latitude: 35.6587, longitude: 139.7));

    expect(calls.single.method, 'reverse');
    expect(calls.single.arguments, {'latitude': 35.6587, 'longitude': 139.7});
    expect(place?.parts, ['일본', '도쿄도', '시부야구', '진난']);
  });

  test('결과가 없으면(바다 등) null', () async {
    handler = (_) async => null;

    expect(await geocoder.reverse((latitude: 0, longitude: 0)), isNull);
  });

  test('네트워크·호출 제한·사용 불가는 GeocodeException 으로 이유를 전한다', () async {
    for (final code in ['network', 'throttled', 'unavailable']) {
      handler = (_) async => throw PlatformException(code: code, message: 'x');

      await expectLater(
        geocoder.reverse((latitude: 1, longitude: 1)),
        throwsA(isA<GeocodeException>().having((e) => e.code, 'code', code)),
      );
    }
  });

  test('응답이 시간 안에 오지 않으면 network 로 본다', () async {
    handler = (_) => Completer<Object?>().future;

    await expectLater(
      const PlatformGeocoder(timeout: Duration(milliseconds: 10))
          .reverse((latitude: 1, longitude: 1)),
      throwsA(isA<GeocodeException>().having((e) => e.code, 'code', 'network')),
    );
  });

  test('채널이 없으면 unavailable', () async {
    messenger.setMockMethodCallHandler(geocoderChannel, null);

    await expectLater(
      geocoder.reverse((latitude: 1, longitude: 1)),
      throwsA(
        isA<GeocodeException>().having((e) => e.code, 'code', 'unavailable'),
      ),
    );
  });
}
