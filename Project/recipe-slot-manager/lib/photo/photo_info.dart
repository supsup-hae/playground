import 'dart:typed_data';

import 'package:recipe_slot_manager/import/fuji_makernote.dart';
import 'package:recipe_slot_manager/import/jpeg_exif.dart';
import 'package:recipe_slot_manager/import/recipe_import.dart';

/// 위도·경도(도). 남위·서경은 음수.
typedef GeoPoint = ({double latitude, double longitude});

/// 사진 한 장의 촬영 정보.
final class PhotoInfo {
  const PhotoInfo({
    this.shotAt,
    this.utcOffset,
    this.location,
    this.model,
    this.imageCount,
    this.recipe = const {},
  });

  /// 촬영 순간 카메라의 벽시계 시각. 시간대는 [utcOffset] 에 따로 둔다.
  final DateTime? shotAt;
  final Duration? utcOffset;
  final GeoPoint? location;
  final String? model;

  /// 후지 MakerNote 의 촬영 번호.
  final int? imageCount;

  /// 후지 MakerNote 의 레시피 값. 후지 사진이 아니면 비어 있다.
  final Map<String, double> recipe;

  /// 기기가 달라도 같은 사진이면 같은 값. 기종·시각·시간대·촬영 번호 중 하나라도 없으면 null.
  String? get key {
    final shotAt = this.shotAt;
    final utcOffset = this.utcOffset;
    if (model == null || shotAt == null || utcOffset == null) return null;
    if (imageCount == null) return null;
    return '$model|${_wallTime(shotAt)}${_offset(utcOffset)}|$imageCount';
  }
}

/// JPEG 앞부분에서 촬영 정보를 읽는다. JPEG 이 아니거나 EXIF 가 깨졌으면 [ImportException].
PhotoInfo readPhotoInfo(Uint8List jpegHead) {
  final exif = readExif(jpegHead);
  final sub = exif.exif ?? const {};
  String? text(Map<int, IfdEntry> ifd, int tag) => switch (ifd[tag]) {
    final entry? => ifdString(exif.tiff, entry),
    _ => null,
  };

  final fujiTags = _fujiTags(exif.tiff, sub[0x927C]);
  final model = text(exif.ifd0, 0x0110);
  return PhotoInfo(
    shotAt: _parseShotAt(text(sub, 0x9003)),
    utcOffset: _parseOffset(text(sub, 0x9011)),
    location: _location(exif),
    model: model == null || model.isEmpty ? null : model,
    // ponytail: ExifTool 은 아래 15비트만 촬영 번호로 본다. X-T5 표본 값(1422)은 영향 없음.
    imageCount: switch (fujiTags[0x1438]) {
      [final count, ...] => count & 0x7FFF,
      _ => null,
    },
    recipe: Map.unmodifiable(decodeFujiRecipe(fujiTags)),
  );
}

Map<int, List<int>> _fujiTags(Uint8List tiff, IfdEntry? makerNote) {
  if (makerNote == null) return const {};
  try {
    return readFujiTags(
      Uint8List.sublistView(
        tiff,
        makerNote.offset,
        makerNote.offset + makerNote.count,
      ),
    );
  } on ImportException {
    return const {};
  }
}

final _shotAtPattern = RegExp(
  r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$',
);

DateTime? _parseShotAt(String? text) {
  final match = text == null ? null : _shotAtPattern.firstMatch(text);
  if (match == null) return null;
  final [year, month, day, hour, minute, second] = [
    for (var i = 1; i <= 6; i++) int.parse(match[i]!),
  ];
  final shotAt = DateTime.utc(year, month, day, hour, minute, second);
  // DateTime 은 13월이나 2월 30일을 다음 해·달로 넘긴다. 넘어갔으면 없는 시각이다.
  final valid =
      shotAt.year == year &&
      shotAt.month == month &&
      shotAt.day == day &&
      shotAt.hour == hour &&
      shotAt.minute == minute &&
      shotAt.second == second;
  return valid ? shotAt : null;
}

final _offsetPattern = RegExp(r'^([+-])(\d{2}):(\d{2})$');

Duration? _parseOffset(String? text) {
  final match = text == null ? null : _offsetPattern.firstMatch(text);
  if (match == null) return null;
  final (hours, minutes) = (int.parse(match[2]!), int.parse(match[3]!));
  if (hours > 14 || minutes > 59) return null;
  final offset = Duration(hours: hours, minutes: minutes);
  return match[1] == '-' ? -offset : offset;
}

/// GPS IFD 의 위도·경도. 방향 문자나 값이 빠졌거나, 범위 밖이거나, 둘 다 0 이면 null.
GeoPoint? _location(Exif exif) {
  final gps = exif.gps;
  if (gps == null) return null;
  double? degrees(int refTag, int valueTag, String positive, String negative) {
    final (ref, value) = (gps[refTag], gps[valueTag]);
    if (ref == null || value == null) return null;
    if (value.type != 5 && value.type != 10) return null;
    final sign = switch (ifdString(exif.tiff, ref)) {
      final r when r == positive => 1,
      final r when r == negative => -1,
      _ => null,
    };
    final parts = ifdRationals(exif.view, value, exif.endian);
    if (sign == null || parts.length != 3 || parts.contains(null)) return null;
    final [d, m, s] = parts.cast<double>();
    return sign * (d + m / 60 + s / 3600);
  }

  final latitude = degrees(0x0001, 0x0002, 'N', 'S');
  final longitude = degrees(0x0003, 0x0004, 'E', 'W');
  if (latitude == null || longitude == null) return null;
  if (latitude.abs() > 90 || longitude.abs() > 180) return null;
  if (latitude == 0 && longitude == 0) return null;
  return (latitude: latitude, longitude: longitude);
}

String _two(int value) => value.toString().padLeft(2, '0');

String _wallTime(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}'
    'T${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

String _offset(Duration offset) {
  final minutes = offset.inMinutes.abs();
  final sign = offset.isNegative ? '-' : '+';
  return '$sign${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
}
