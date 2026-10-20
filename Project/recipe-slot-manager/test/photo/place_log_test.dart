import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/photo/place_log.dart';

void main() {
  PlaceLog shibuya() => PlaceLog(
    id: 'log-1',
    loggedAt: DateTime.utc(2025, 12, 31, 16, 30),
    utcOffset: const Duration(hours: 9),
    location: (latitude: 35.6587, longitude: 139.7005),
    accuracy: 12.5,
    loadoutId: 'loadout-1',
    loadoutName: '도쿄 밤',
    slots: ['Eterna 밤', null, null, null, null, null, 'Classic Neg.'],
    model: 'X-T5',
  );

  test('JSON 으로 저장했다가 그대로 읽는다', () {
    final read = PlaceLog.fromJson(shibuya().toJson());

    expect(read.id, 'log-1');
    expect(read.loggedAt, DateTime.utc(2025, 12, 31, 16, 30));
    expect(read.utcOffset, const Duration(hours: 9));
    expect(read.location, (latitude: 35.6587, longitude: 139.7005));
    expect(read.accuracy, 12.5);
    expect(read.loadoutName, '도쿄 밤');
    expect(read.slots, [
      'Eterna 밤',
      null,
      null,
      null,
      null,
      null,
      'Classic Neg.',
    ]);
    expect(read.model, 'X-T5');
    expect(read.missingReason, isNull);
  });

  test('위치 없는 기록은 이유를 남긴다', () {
    final log = PlaceLog(
      id: 'log-2',
      loggedAt: DateTime.utc(2026, 10, 20),
      utcOffset: Duration.zero,
      loadoutId: 'loadout-1',
      loadoutName: '아침',
      slots: List.filled(7, null),
      missingReason: '위치 권한이 없습니다',
    );

    final read = PlaceLog.fromJson(log.toJson());

    expect(read.location, isNull);
    expect(read.accuracy, isNull);
    expect(read.missingReason, '위치 권한이 없습니다');
  });

  test('현지 시각은 UTC 에 시간대를 더한 벽시계 시각', () {
    final local = shibuya().localTime;

    expect((local.year, local.month, local.day), (2026, 1, 1));
    expect((local.hour, local.minute), (1, 30));
  });

  test('슬롯이 7칸이 아니거나 칸이 틀리면 형식 오류', () {
    final json = shibuya().toJson();

    expect(
      () => PlaceLog.fromJson({
        ...json,
        'slots': <String?>['a'],
      }),
      throwsFormatException,
    );
    expect(
      () => PlaceLog.fromJson({
        ...json,
        'slots': [1, null, null, null, null, null, null],
      }),
      throwsFormatException,
    );
    expect(
      () => PlaceLog.fromJson({...json, 'latitude': 'x'}),
      throwsFormatException,
    );
    expect(() => PlaceLog.fromJson('x'), throwsFormatException);
  });
}
