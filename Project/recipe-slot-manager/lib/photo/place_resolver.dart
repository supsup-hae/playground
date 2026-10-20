import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/photo/geocoder.dart';
import 'package:recipe_slot_manager/photo/photo_index_store.dart';
import 'package:recipe_slot_manager/photo/photo_info.dart';
import 'package:recipe_slot_manager/photo/place.dart';
import 'package:recipe_slot_manager/photo/place_log_store.dart';
import 'package:recipe_slot_manager/photo/place_store.dart';
import 'package:recipe_slot_manager/util/serial_queue.dart';

/// 이 오류면 다음 좌표도 실패하므로 멈춘다.
const _stopCodes = {'network', 'throttled', 'unavailable'};

/// 색인한 사진과 세트 저장 기록의 좌표 중 장소 이름이 없는 것만 기기 주소 변환으로 묻고 캐시에 저장한다.
class PlaceResolver {
  PlaceResolver({
    required this.photos,
    required this.places,
    required this.geocoder,
    required this.log,
    this.logs,
    this.interval = const Duration(seconds: 1),
    Future<void> Function(Duration)? wait,
  }) : _wait = wait ?? Future<void>.delayed;

  final PhotoIndexStore photos;
  final PlaceStore places;
  final Geocoder geocoder;
  final CameraLog log;
  final PlaceLogStore? logs;

  /// 요청 사이 간격. 기기 주소 변환은 앱마다 호출 수를 제한한다.
  final Duration interval;
  final Future<void> Function(Duration) _wait;
  final _queue = SerialQueue();

  /// 이름이 없는 키를 차례로 묻는다. 연결 없음·호출 제한·사용 불가([_stopCodes])면 거기서 멈추고,
  /// 그 밖의 오류는 그 키만 건너뛴다. 남은 키와 건너뛴 키는 다음 호출에서 다시 묻는다.
  /// 겹쳐 부르면 앞 호출이 끝난 뒤 돈다.
  Future<({int resolved, int remaining})> resolveMissing({
    void Function(int done, int total)? onProgress,
  }) => _queue.run(() => _resolveMissing(onProgress));

  Future<({int resolved, int remaining})> _resolveMissing(
    void Function(int done, int total)? onProgress,
  ) async {
    final missing = <String, GeoPoint>{};
    for (final location in [
      for (final photo in photos.photos) photo.info?.location,
      ...?logs?.logs.map((log) => log.location),
    ]) {
      if (location == null) continue;
      final key = placeKey(location);
      if (!places.contains(key)) missing.putIfAbsent(key, () => location);
    }
    if (missing.isEmpty) return (resolved: 0, remaining: 0);

    var resolved = 0;
    var failed = 0;
    String? lastError;
    onProgress?.call(0, missing.length);
    for (final MapEntry(:key, value: location) in missing.entries) {
      if (resolved + failed > 0) await _wait(interval);
      try {
        final place = await geocoder.reverse(location);
        await places.save(key, place ?? const Place());
        resolved++;
      } on GeocodeException catch (e) {
        if (_stopCodes.contains(e.code)) {
          final remaining = missing.length - resolved;
          log.add('장소 이름: 받음 $resolved, 남음 $remaining (${e.message})');
          return (resolved: resolved, remaining: remaining);
        }
        failed++;
        lastError = e.message;
      }
      onProgress?.call(resolved + failed, missing.length);
    }
    log.add(
      failed == 0
          ? '장소 이름: 받음 $resolved'
          : '장소 이름: 받음 $resolved, 실패 $failed ($lastError)',
    );
    return (resolved: resolved, remaining: failed);
  }
}
