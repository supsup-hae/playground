import 'dart:math';

import 'package:recipe_slot_manager/photo/photo_info.dart';

/// 지도에서 한 점으로 보일 사진 묶음. [center] 는 들어 있는 점의 평균.
typedef MapCluster<T> = ({GeoPoint center, List<T> items});

/// [items] 를 확대 수준 [zoom] 의 화면 픽셀 격자([cellPixels] 크기 칸)로 묶는다.
/// 좌표는 웹 메르카토르(256 px 타일)로 화면 위치를 구한다.
List<MapCluster<T>> clusterPoints<T>(
  Iterable<T> items,
  GeoPoint Function(T item) at,
  double zoom, {
  double cellPixels = 60,
}) {
  final scale = 256 * pow(2, zoom);
  final cells = <(int, int), List<T>>{};
  for (final item in items) {
    final point = at(item);
    final x = (point.longitude + 180) / 360 * scale;
    final lat = point.latitude.clamp(-85.05, 85.05) * pi / 180;
    final y = (1 - log(tan(lat) + 1 / cos(lat)) / pi) / 2 * scale;
    final cell = ((x / cellPixels).floor(), (y / cellPixels).floor());
    (cells[cell] ??= []).add(item);
  }
  return [
    for (final members in cells.values)
      (
        center: (
          latitude:
              members.map((m) => at(m).latitude).reduce((a, b) => a + b) /
              members.length,
          longitude:
              members.map((m) => at(m).longitude).reduce((a, b) => a + b) /
              members.length,
        ),
        items: members,
      ),
  ];
}
