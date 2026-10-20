import 'package:recipe_slot_manager/photo/photo_info.dart';
import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';

/// 세트를 카메라 C1–C7에 저장한 기록 하나: 언제, 어디서, 어떤 세트를.
final class PlaceLog {
  PlaceLog({
    required this.id,
    required this.loggedAt,
    required this.utcOffset,
    this.location,
    this.accuracy,
    required this.loadoutId,
    required this.loadoutName,
    required List<String?> slots,
    this.model,
    this.missingReason,
  }) : slots = List.unmodifiable(slots) {
    if (slots.length != FujiProp.slotCount) {
      throw ArgumentError.value(slots, 'slots', 'C1–C7 7칸이 아님');
    }
  }

  /// 형식이 맞지 않으면 [FormatException].
  factory PlaceLog.fromJson(Object? json) {
    if (json
        case {
          'id': final String id,
          'loggedAt': final String loggedAt,
          'utcOffsetMinutes': final int offset,
          'loadoutId': final String loadoutId,
          'loadoutName': final String loadoutName,
          'slots': final List<dynamic> slots,
        }
        when slots.length == FujiProp.slotCount &&
            slots.every((s) => s == null || s is String)) {
      String? text(String key) => switch (json[key]) {
        null => null,
        final String value => value,
        final other => throw FormatException('저장 기록 형식 오류', other),
      };
      return PlaceLog(
        id: id,
        loggedAt: parseUtc(loggedAt),
        utcOffset: Duration(minutes: offset),
        location: switch ((json['latitude'], json['longitude'])) {
          (null, null) => null,
          (final num latitude, final num longitude) => (
            latitude: latitude.toDouble(),
            longitude: longitude.toDouble(),
          ),
          final other => throw FormatException('저장 기록 형식 오류', other),
        },
        accuracy: switch (json['accuracy']) {
          null => null,
          final num meters => meters.toDouble(),
          final other => throw FormatException('저장 기록 형식 오류', other),
        },
        loadoutId: loadoutId,
        loadoutName: loadoutName,
        slots: slots.cast<String?>(),
        model: text('model'),
        missingReason: text('missingReason'),
      );
    }
    throw FormatException('저장 기록 형식 오류', json);
  }

  final String id;

  /// 저장을 마친 시각(UTC).
  final DateTime loggedAt;

  /// 그때 기기의 시간대.
  final Duration utcOffset;

  /// 휴대폰 위치. 받지 못했으면 null 이고 [missingReason] 에 이유가 있다.
  final GeoPoint? location;

  /// 위치 오차 반경(m).
  final double? accuracy;

  final String loadoutId;

  /// 저장할 때의 세트 이름. 세트를 나중에 고쳐도 기록은 그대로다.
  final String loadoutName;

  /// C1–C7 순서로 넣은 레시피 이름. null 은 그 슬롯을 그대로 둔 칸.
  final List<String?> slots;

  /// 카메라 기종.
  final String? model;

  final String? missingReason;

  /// 그때 기기의 벽시계 시각. 연도 조건과 화면 표시에 쓴다.
  DateTime get localTime => loggedAt.add(utcOffset);

  Map<String, Object?> toJson() => {
    'id': id,
    'loggedAt': loggedAt.toUtc().toIso8601String(),
    'utcOffsetMinutes': utcOffset.inMinutes,
    if (location case final location?) ...{
      'latitude': location.latitude,
      'longitude': location.longitude,
    },
    'accuracy': ?accuracy,
    'loadoutId': loadoutId,
    'loadoutName': loadoutName,
    'slots': slots,
    'model': ?model,
    'missingReason': ?missingReason,
  };
}
