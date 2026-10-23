import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/photo/photo_index_store.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/photo/place_log.dart';
import 'package:recipe_slot_manager/photo/place_log_store.dart';
import 'package:recipe_slot_manager/sync/remote_photos.dart';

/// 사진 색인과 세트 저장 기록을 원격과 맞춘다. 원격 행은 지우지 않고 더하기만 한다.
///
/// - 사진: 원격 행을 모두 받아 "다른 기기" 사진으로 둔다. 이 기기 사진 중 원격에 없거나, 원격에
///   위치가 없는데 이 기기에 위치가 있는 것만 올린다. 촬영 시각이 없는 사진은 올리지 않는다
/// - 기록: 없는 id 만 받고, 원격에 없는 이 기기 기록만 올린다
///
/// 원격에 닿지 못하면 예외를 그대로 던진다.
class PhotoSync {
  PhotoSync({
    required this.photos,
    required this.logs,
    required this.remote,
    required this.log,
  });

  final PhotoIndexStore photos;
  final PlaceLogStore logs;
  final RemotePhotos remote;
  final CameraLog log;

  Future<void> sync() async {
    var skipped = 0;
    final remotePhotos = <String, RemotePhoto>{};
    for (final body in await remote.fetchPhotos()) {
      try {
        final photo = RemotePhoto.fromJson(body);
        remotePhotos[photo.key] = photo;
      } on FormatException {
        skipped++;
      }
    }
    await photos.replaceOtherDevice([
      for (final photo in remotePhotos.values)
        IndexedPhoto(
          sourceId: otherDeviceSourceId,
          file: (id: photo.key, name: photo.name, size: 0, modifiedMs: 0),
          info: photo.info,
        ),
    ]);

    final upPhotos = <RemotePhoto>[];
    for (final photo in photos.localPhotos) {
      final key = PhotoIndexStore.photoKey(photo);
      final info = photo.info;
      if (key == null || info == null) continue;
      final known = remotePhotos[key];
      if (known == null ||
          (known.info.location == null && info.location != null)) {
        upPhotos.add(RemotePhoto(key: key, name: photo.file.name, info: info));
      }
    }
    await remote.upsertPhotos(upPhotos);

    final remoteLogs = <PlaceLog>[];
    for (final body in await remote.fetchLogs()) {
      try {
        remoteLogs.add(PlaceLog.fromJson(body));
      } on FormatException {
        skipped++;
      }
    }
    final remoteIds = {for (final l in remoteLogs) l.id};
    final upLogs = [
      for (final l in logs.logs)
        if (!remoteIds.contains(l.id)) l,
    ];
    final added = await logs.addAll(remoteLogs);
    await remote.upsertLogs(upLogs);

    log.add(
      '사진 동기화: 사진 받음 ${remotePhotos.length}, 올림 ${upPhotos.length}, '
      '기록 받음 $added, 올림 ${upLogs.length}, 건너뜀 $skipped',
    );
  }
}
