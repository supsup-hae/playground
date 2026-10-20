import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/photo/photo_info.dart';
import 'package:recipe_slot_manager/photo/place.dart';
import 'package:recipe_slot_manager/util/atomic_json.dart';
import 'package:recipe_slot_manager/util/serial_queue.dart';

/// 좌표 키([placeKey]) → 장소 이름 캐시. 기기의 `places.json` 에 저장한다. 이름이 없는 장소(바다
/// 등)도 빈 [Place] 로 저장해 다시 묻지 않는다.
class PlaceStore extends ChangeNotifier {
  PlaceStore(this.directory, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Directory directory;
  final DateTime Function() _clock;
  final _places = <String, Place>{};
  final _writes = SerialQueue();

  File get _file => File(p.join(directory.path, 'places.json'));

  bool contains(String key) => _places.containsKey(key);

  Place? place(String key) => _places[key];

  Place? placeOf(GeoPoint? location) =>
      location == null ? null : _places[placeKey(location)];

  /// 불러올 때 읽지 못해 옮겨 둔 파일 설명. 다음 [load] 에서 비워진다.
  List<String> get loadErrors => List.unmodifiable(_loadErrors);
  final _loadErrors = <String>[];

  /// 파일이 없으면 빈 캐시. 형식이 맞지 않는 파일은 `places.json.corrupt-<시각>` 으로 옮기고
  /// [loadErrors] 에 남긴 뒤 빈 캐시로 시작한다.
  Future<void> load() async {
    _loadErrors.clear();
    final read = await readJsonFile(
      _file,
      (json) => switch (json) {
        {'places': final Map<String, dynamic> places} => {
          for (final MapEntry(:key, :value) in places.entries)
            key: Place.fromJson(value),
        },
        _ => throw FormatException('장소 파일 형식 오류', json),
      },
      now: _clock(),
      errors: _loadErrors,
    );
    _places
      ..clear()
      ..addAll(read ?? const {});
    notifyListeners();
  }

  Future<void> save(String key, Place place) async {
    _places[key] = place;
    await _writes.run(
      () => writeJsonAtomically(_file, {
        'places': {
          for (final MapEntry(:key, :value) in _places.entries)
            key: value.toJson(),
        },
      }),
    );
    notifyListeners();
  }
}
