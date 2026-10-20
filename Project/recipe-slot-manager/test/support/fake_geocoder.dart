import 'package:recipe_slot_manager/photo/geocoder.dart';
import 'package:recipe_slot_manager/photo/photo_info.dart';
import 'package:recipe_slot_manager/photo/place.dart';

/// 위도가 0 이면 이름 없음, 그 밖에는 `나라 <위도>`. 요청을 기록하고, [failAt] 번째(0부터) 요청에서 [failure] 를 던진다.
class FakeGeocoder implements Geocoder {
  final requests = <GeoPoint>[];
  int? failAt;
  GeocodeException failure = const GeocodeException('network', '연결 없음');

  @override
  Future<Place?> reverse(GeoPoint location) async {
    if (requests.length == failAt) {
      requests.add(location);
      throw failure;
    }
    requests.add(location);
    if (location.latitude == 0) return null;
    return Place(country: '나라 ${location.latitude}');
  }
}
