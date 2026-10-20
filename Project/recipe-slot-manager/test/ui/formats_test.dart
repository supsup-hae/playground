import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/photo/photo_info.dart';
import 'package:recipe_slot_manager/ui/formats.dart';

void main() {
  final t = DateTime.utc(2025, 3, 4, 5, 6);

  test('날짜·시각·날짜와 시각', () {
    expect(formatDate(t), '2025-03-04');
    expect(formatTime(t), '05:06');
    expect(formatDateTime(t), '2025-03-04 05:06');
  });

  test('촬영 시각은 시간대를 붙이고, 시각이 없으면 null', () {
    expect(
      formatShotAt(PhotoInfo(shotAt: t, utcOffset: const Duration(hours: 9))),
      '2025-03-04 05:06 (+09:00)',
    );
    expect(
      formatShotAt(
        PhotoInfo(
          shotAt: t,
          utcOffset: const Duration(hours: -3, minutes: -30),
        ),
      ),
      '2025-03-04 05:06 (-03:30)',
    );
    expect(formatShotAt(PhotoInfo(shotAt: t)), '2025-03-04 05:06');
    expect(formatShotAt(const PhotoInfo()), isNull);
  });
}
