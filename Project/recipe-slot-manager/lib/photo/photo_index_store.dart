import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/util/atomic_json.dart';
import 'package:recipe_slot_manager/util/serial_queue.dart';

/// 색인 요약. [byFilmSimulation] 은 필름 시뮬레이션 코드 → 사진 수, 많은 순.
typedef PhotoSummary = ({
  int total,
  int withLocation,
  int failed,
  Map<int, int> byFilmSimulation,
});

/// 사진 출처와 색인 항목을 기기의 `photos.json` 에 저장한다.
class PhotoIndexStore extends ChangeNotifier {
  PhotoIndexStore(this.directory, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Directory directory;
  final DateTime Function() _clock;
  final _sources = <String, PhotoSource>{};

  /// 출처 id → 그 출처의 항목.
  final _photos = <String, List<IndexedPhoto>>{};

  /// 저장이 겹쳐도 쓰는 시점의 최신 상태를 순서대로 쓴다.
  final _writes = SerialQueue();

  File get _file => File(p.join(directory.path, 'photos.json'));

  /// 추가한 순서.
  List<PhotoSource> get sources => List.unmodifiable(_sources.values);

  PhotoSource? sourceById(String id) => _sources[id];

  /// 모든 출처의 사진. Mac 과 휴대폰에 같은 사진이 있으면 하나만 둔다([_sameKey]). 위치가 든
  /// 쪽을 고르고, 둘 다 같으면 먼저 추가한 출처의 것을 쓴다.
  List<IndexedPhoto> get photos {
    final unique = <String, IndexedPhoto>{};
    for (final photo in _photos.values.expand((list) => list)) {
      final key = _sameKey(photo);
      final kept = unique[key];
      if (kept == null ||
          (kept.info?.location == null && photo.info?.location != null)) {
        unique[key] = photo;
      }
    }
    return unique.values.toList();
  }

  /// 같은 사진이면 같은 값: 파일 이름(대소문자 무시)과 촬영 시각. 카메라 파일 번호는 9999 다음에
  /// 다시 쓰이므로 시각을 함께 본다. 촬영 시각이 없거나 읽지 못한 사진은 출처와 파일마다 따로 둔다.
  static String _sameKey(IndexedPhoto photo) => switch (photo.info?.shotAt) {
    final shotAt? =>
      '${photo.file.name.toLowerCase()}|${shotAt.toIso8601String()}',
    null => '${photo.sourceId}|${photo.file.id}',
  };

  List<IndexedPhoto> photosOf(String sourceId) =>
      List.unmodifiable(_photos[sourceId] ?? const <IndexedPhoto>[]);

  /// [photos] 기준이라 같은 사진은 한 번 센다.
  PhotoSummary get summary {
    final all = photos;
    final counts = <int, int>{};
    for (final photo in all) {
      final code = photo.info?.recipe['filmSimulation']?.toInt();
      if (code != null) counts[code] = (counts[code] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return (
      total: all.length,
      withLocation: all.where((p) => p.info?.location != null).length,
      failed: all.where((p) => p.error != null).length,
      byFilmSimulation: Map.fromEntries(sorted),
    );
  }

  /// 불러올 때 읽지 못해 옮겨 둔 파일 설명. 다음 [load] 에서 비워진다.
  List<String> get loadErrors => List.unmodifiable(_loadErrors);
  final _loadErrors = <String>[];

  /// 파일이 없으면 빈 색인. 형식이 맞지 않는 파일은 `photos.json.corrupt-<시각>` 으로 옮기고
  /// [loadErrors] 에 남긴 뒤 빈 색인으로 시작한다.
  Future<void> load() async {
    _loadErrors.clear();
    final read = await readJsonFile(
      _file,
      _parse,
      now: _clock(),
      errors: _loadErrors,
    );
    _sources
      ..clear()
      ..addAll({
        for (final source in read?.sources ?? const []) source.id: source,
      });
    _photos.clear();
    for (final photo in read?.photos ?? const <IndexedPhoto>[]) {
      (_photos[photo.sourceId] ??= []).add(photo);
    }
    notifyListeners();
  }

  static ({List<PhotoSource> sources, List<IndexedPhoto> photos}) _parse(
    Object? json,
  ) {
    if (json case {
      'sources': final List<dynamic> sources,
      'photos': final List<dynamic> photos,
    }) {
      return (
        sources: sources.map(PhotoSource.fromJson).toList(),
        photos: photos.map(IndexedPhoto.fromJson).toList(),
      );
    }
    throw FormatException('사진 색인 파일 형식 오류', json);
  }

  /// 출처를 더하거나 바꾼다.
  Future<void> saveSource(PhotoSource source) async {
    _sources[source.id] = source;
    await _write();
  }

  /// 출처와 그 출처의 항목을 지운다. 사진 파일은 건드리지 않는다.
  Future<void> removeSource(String sourceId) async {
    _sources.remove(sourceId);
    _photos.remove(sourceId);
    await _write();
  }

  /// 출처의 항목을 [photos] 로 바꾸고 출처의 색인 시각을 남긴다.
  Future<void> replacePhotos(String sourceId, List<IndexedPhoto> photos) async {
    final source = _sources[sourceId];
    if (source == null) return;
    _sources[sourceId] = source.copyWith(indexedAt: _clock().toUtc());
    _photos[sourceId] = List.of(photos);
    await _write();
  }

  Future<void> _write() async {
    await _writes.run(
      () => writeJsonAtomically(_file, {
        'sources': [for (final s in _sources.values) s.toJson()],
        // 화면용 [photos] 가 아니라 출처별 항목 전체를 저장한다.
        'photos': [
          for (final list in _photos.values)
            for (final p in list) p.toJson(),
        ],
      }),
    );
    notifyListeners();
  }
}
