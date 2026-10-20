import 'package:recipe_slot_manager/photo/photo_info.dart';

/// `2025-10-12`.
String formatDate(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';

/// `15:26`.
String formatTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// `2025-10-12 15:26`.
String formatDateTime(DateTime t) => '${formatDate(t)} ${formatTime(t)}';

/// `2025-10-12 15:26 (+09:00)`. 시간대를 모르면 붙이지 않고, 시각이 없으면 null.
String? formatShotAt(PhotoInfo info) {
  final t = info.shotAt;
  if (t == null) return null;
  final offset = switch (info.utcOffset) {
    final o? =>
      ' (${o.isNegative ? '-' : '+'}'
          '${_two(o.inMinutes.abs() ~/ 60)}:${_two(o.inMinutes.abs() % 60)})',
    null => '',
  };
  return '${formatDateTime(t)}$offset';
}

String _two(int value) => value.toString().padLeft(2, '0');
