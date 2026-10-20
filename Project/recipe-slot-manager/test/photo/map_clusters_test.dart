import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/photo/map_clusters.dart';
import 'package:recipe_slot_manager/photo/photo_info.dart';

void main() {
  GeoPoint at(String name) => switch (name) {
    'shibuya' => (latitude: 35.6587, longitude: 139.7005),
    'harajuku' => (latitude: 35.6702, longitude: 139.7027),
    'osaka' => (latitude: 34.6662, longitude: 135.5012),
    'east' => (latitude: 0.0, longitude: 179.99),
    'west' => (latitude: 0.0, longitude: -179.99),
    _ => throw ArgumentError(name),
  };

  test('멀리 보면 가까운 곳끼리 묶이고, 가까이 보면 나뉜다', () {
    final points = ['shibuya', 'harajuku', 'osaka'];

    final far = clusterPoints(points, at, 5);
    final near = clusterPoints(points, at, 14);

    expect(far.map((c) => c.items.length).toList()..sort(), [1, 2]);
    expect(near, hasLength(3));
  });

  test('묶음의 가운데는 들어 있는 점의 평균', () {
    final cluster = clusterPoints(['shibuya', 'harajuku'], at, 5).single;

    expect(cluster.center.latitude, closeTo((35.6587 + 35.6702) / 2, 1e-9));
    expect(cluster.center.longitude, closeTo((139.7005 + 139.7027) / 2, 1e-9));
  });

  test('날짜 변경선 양쪽은 화면에서 떨어져 있어 따로 묶인다', () {
    expect(clusterPoints(['east', 'west'], at, 3), hasLength(2));
  });

  test('점이 없으면 묶음도 없다', () {
    expect(clusterPoints(<String>[], at, 5), isEmpty);
  });
}
