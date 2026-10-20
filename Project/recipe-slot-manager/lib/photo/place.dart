import 'package:recipe_slot_manager/photo/photo_info.dart';

/// [location] 을 소수 넷째 자리(약 10 m)로 반올림한 장소 캐시 키. 예: `35.6587,139.7005`.
String placeKey(GeoPoint location) =>
    '${_fixed(location.latitude)},${_fixed(location.longitude)}';

String _fixed(double value) {
  final text = value.toStringAsFixed(4);
  return text == '-0.0000' ? '0.0000' : text;
}

/// 좌표의 주소 이름. 기기의 주소 변환이 준 값이며, 칸마다 비어 있을 수 있다.
/// 모든 칸이 비었으면(바다 등) 이름이 없는 장소다.
final class Place {
  const Place({
    this.country,
    this.admin,
    this.locality,
    this.subLocality,
    this.thoroughfare,
  });

  factory Place.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw FormatException('장소 형식 오류', json);
    }
    String? text(String key) => switch (json[key]) {
      null => null,
      final String value => value,
      final other => throw FormatException('장소 형식 오류', other),
    };
    return Place(
      country: text('country'),
      admin: text('admin'),
      locality: text('locality'),
      subLocality: text('subLocality'),
      thoroughfare: text('thoroughfare'),
    );
  }

  /// 나라 (일본).
  final String? country;

  /// 광역 행정구역 (도쿄도).
  final String? admin;

  /// 도시·구 (시부야구).
  final String? locality;

  /// 동네 (진난).
  final String? subLocality;

  /// 길 이름.
  final String? thoroughfare;

  /// 나라부터 길까지 비지 않은 칸.
  List<String> get parts => [
    for (final part in [country, admin, locality, subLocality, thoroughfare])
      if (part != null && part.isNotEmpty) part,
  ];

  bool get isEmpty => parts.isEmpty;

  /// 화면에 보일 짧은 이름: 동네·도시·나라 순, 빈 칸은 건너뛴다. 동네와 도시가 없으면 광역을 쓴다.
  String get label {
    final local = [
      for (final part in [subLocality, locality])
        if (part != null && part.isNotEmpty) part,
    ];
    return [
      ...local,
      if (local.isEmpty && admin != null && admin!.isNotEmpty) admin!,
      if (country != null && country!.isNotEmpty) country!,
    ].join(', ');
  }

  Map<String, String> toJson() => {
    'country': ?country,
    'admin': ?admin,
    'locality': ?locality,
    'subLocality': ?subLocality,
    'thoroughfare': ?thoroughfare,
  };
}
