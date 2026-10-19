import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/import/recipe_import.dart';
import 'package:recipe_slot_manager/photo/photo_index_store.dart';
import 'package:recipe_slot_manager/photo/photo_info.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/util/serial_queue.dart';

/// 색인 한 번의 결과.
typedef PhotoIndexResult = ({
  int added,
  int changed,
  int removed,
  int failed,
  Duration elapsed,
});

/// 출처의 사진 목록을 색인과 비교해 새 사진과 바뀐 사진만 읽고 저장한다.
class PhotoIndexer {
  PhotoIndexer(this.store, {required this.readers, required this.log});

  final PhotoIndexStore store;
  final Map<PhotoSourceKind, PhotoSourceReader> readers;
  final CameraLog log;

  /// 색인을 하나씩 한다. 겹친 색인은 앞 색인이 저장한 결과와 비교한다.
  final _queue = SerialQueue();

  /// [onProgress] 는 읽을 사진 수 기준 (읽은 수, 전체)이다. 출처 목록을 읽지 못하면
  /// [PhotoSourceException] 을 그대로 던지고 색인은 바꾸지 않는다.
  Future<PhotoIndexResult> index(
    PhotoSource source, {
    void Function(int done, int total)? onProgress,
  }) => _queue.run(() => _index(source, onProgress));

  Future<PhotoIndexResult> _index(
    PhotoSource source,
    void Function(int done, int total)? onProgress,
  ) async {
    final watch = Stopwatch()..start();
    final reader =
        readers[source.kind] ??
        (throw const PhotoSourceException('이 기기에서는 이 출처를 읽을 수 없습니다'));
    final files = await reader.list(source);
    final known = {for (final p in store.photosOf(source.id)) p.file.id: p};

    final keep = <IndexedPhoto>[];
    final toRead = <PhotoFile>[];
    for (final file in files) {
      final old = known[file.id];
      if (old != null && !_needsRead(old, file)) {
        keep.add(old);
      } else {
        toRead.add(file);
      }
    }

    onProgress?.call(0, toRead.length);
    final read = <IndexedPhoto>[];
    for (final file in toRead) {
      read.add(await _read(reader, source, file));
      onProgress?.call(read.length, toRead.length);
    }
    await store.replacePhotos(source.id, [...keep, ...read]);

    final added = toRead.where((f) => !known.containsKey(f.id)).length;
    final ids = {for (final f in files) f.id};
    final result = (
      added: added,
      changed: toRead.length - added,
      removed: known.keys.where((id) => !ids.contains(id)).length,
      failed: read.where((p) => p.error != null).length,
      elapsed: watch.elapsed,
    );
    log.add(
      '사진 색인: 새로 ${result.added}, 바뀜 ${result.changed}, '
      '지움 ${result.removed}, 실패 ${result.failed}, '
      '${(result.elapsed.inMilliseconds / 1000).toStringAsFixed(1)}초',
    );
    return result;
  }

  /// 크기·수정 시각이 바뀌었거나, 지난번에 위치가 가려진 채 읽었으면 다시 읽는다.
  bool _needsRead(IndexedPhoto old, PhotoFile file) =>
      old.file.size != file.size ||
      old.file.modifiedMs != file.modifiedMs ||
      old.locationRedacted;

  Future<IndexedPhoto> _read(
    PhotoSourceReader reader,
    PhotoSource source,
    PhotoFile file,
  ) async {
    try {
      final head = await reader.readHead(source, file);
      return IndexedPhoto(
        sourceId: source.id,
        file: file,
        info: readPhotoInfo(head.bytes),
        locationRedacted: head.locationRedacted,
      );
    } on ImportException catch (e) {
      return IndexedPhoto(sourceId: source.id, file: file, error: e.message);
    } on PhotoSourceException catch (e) {
      return IndexedPhoto(sourceId: source.id, file: file, error: e.message);
    }
  }
}
