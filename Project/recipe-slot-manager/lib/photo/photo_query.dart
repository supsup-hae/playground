import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/photo/place.dart';
import 'package:recipe_slot_manager/photo/place_store.dart';
import 'package:recipe_slot_manager/recipe/recipe_fields.dart';

/// 사진 찾기 조건. 비어 있는 칸은 조건이 아니다.
final class PhotoFilter {
  const PhotoFilter({
    this.year,
    this.country,
    this.admin,
    this.locality,
    this.films = const {},
    this.noLocationOnly = false,
    this.text = '',
  });

  /// 촬영 연도(카메라 벽시계 기준).
  final int? year;
  final String? country;
  final String? admin;
  final String? locality;

  /// 필름 시뮬레이션 코드. 하나라도 맞으면 된다.
  final Set<int> films;

  /// 위치가 없는 사진만.
  final bool noLocationOnly;

  /// 검색어. 띄어쓰기로 나눈 낱말이 모두 맞아야 한다.
  final String text;

  /// 칸을 바꾼 새 조건. 비울 수 있는 칸은 값을 돌려주는 함수로 받는다(`year: () => null`).
  PhotoFilter copyWith({
    int? Function()? year,
    String? Function()? country,
    String? Function()? admin,
    String? Function()? locality,
    Set<int>? films,
    bool? noLocationOnly,
    String? text,
  }) => PhotoFilter(
    year: year == null ? this.year : year(),
    country: country == null ? this.country : country(),
    admin: admin == null ? this.admin : admin(),
    locality: locality == null ? this.locality : locality(),
    films: films ?? this.films,
    noLocationOnly: noLocationOnly ?? this.noLocationOnly,
    text: text ?? this.text,
  );
}

/// 찾은 사진과 그 장소 이름.
typedef PhotoEntry = ({IndexedPhoto photo, Place? place});

/// 조건에 맞는 사진(읽지 못한 사진은 뺀다), 촬영 시각 최신순. 시각이 없는 사진은 맨 뒤.
List<PhotoEntry> queryPhotos(
  Iterable<IndexedPhoto> photos,
  PlaceStore places,
  PhotoFilter filter,
) {
  final words = filter.text
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final entries = <PhotoEntry>[];
  for (final photo in photos) {
    final info = photo.info;
    if (info == null) continue;
    final place = places.placeOf(info.location);
    if (filter.year != null && info.shotAt?.year != filter.year) continue;
    if (filter.noLocationOnly && info.location != null) continue;
    if (filter.country != null && place?.country != filter.country) continue;
    if (filter.admin != null && place?.admin != filter.admin) continue;
    if (filter.locality != null && place?.locality != filter.locality) {
      continue;
    }
    final film = info.recipe['filmSimulation']?.toInt();
    if (filter.films.isNotEmpty && !filter.films.contains(film)) continue;
    if (words.isNotEmpty) {
      final haystack = [
        ...?place?.parts,
        photo.file.name,
        if (film != null) filmName(film),
      ].map((s) => s.toLowerCase()).toList();
      if (!words.every((w) => haystack.any((h) => h.contains(w)))) continue;
    }
    entries.add((photo: photo, place: place));
  }
  entries.sort((a, b) {
    final (x, y) = (a.photo.info?.shotAt, b.photo.info?.shotAt);
    if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
    return y.compareTo(x);
  });
  return entries;
}

/// 필름 시뮬레이션 코드의 화면 이름 (Eterna).
String filmName(int code) =>
    fieldById['filmSimulation']!.display(code.toDouble());

/// 필터 선택지. 지역은 고른 상위 지역 안의 것만, 많은 순.
typedef PhotoFacets = ({
  List<int> years,
  List<String> countries,
  List<String> admins,
  List<String> localities,
  Map<int, int> films,
});

/// [photos] 전체에서 선택지를 만든다. 광역은 [PhotoFilter.country], 도시는
/// [PhotoFilter.admin] 을 골랐을 때만 채운다.
PhotoFacets photoFacets(
  Iterable<IndexedPhoto> photos,
  PlaceStore places,
  PhotoFilter filter,
) {
  final years = <int>{};
  final countries = <String, int>{};
  final admins = <String, int>{};
  final localities = <String, int>{};
  final films = <int, int>{};
  void count(Map<String, int> map, String? key) {
    if (key != null && key.isNotEmpty) map[key] = (map[key] ?? 0) + 1;
  }

  for (final photo in photos) {
    final info = photo.info;
    if (info == null) continue;
    if (info.shotAt case final shotAt?) years.add(shotAt.year);
    if (info.recipe['filmSimulation']?.toInt() case final film?) {
      films[film] = (films[film] ?? 0) + 1;
    }
    final place = places.placeOf(info.location);
    if (place == null) continue;
    count(countries, place.country);
    if (filter.country != null && place.country == filter.country) {
      count(admins, place.admin);
      if (filter.admin != null && place.admin == filter.admin) {
        count(localities, place.locality);
      }
    }
  }
  List<String> byCount(Map<String, int> map) =>
      (map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .map((e) => e.key)
          .toList();
  return (
    years: years.toList()..sort((a, b) => b.compareTo(a)),
    countries: byCount(countries),
    admins: byCount(admins),
    localities: byCount(localities),
    films: Map.fromEntries(
      films.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    ),
  );
}
