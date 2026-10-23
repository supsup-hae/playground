import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/library/loadout.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';
import 'package:recipe_slot_manager/sync/photo_sync.dart';
import 'package:recipe_slot_manager/sync/remote_library.dart';
import 'package:recipe_slot_manager/util/atomic_json.dart';

/// 기기 보관함과 원격 보관함을 맞춘다.
///
/// 원격 행을 모두 받아 id 별로 updatedAt 이 늦은 쪽을 남기고([LibraryStore.mergeRemote]),
/// 그다음 원격에 없거나 원격보다 늦게 고친 기기 행만 올린다. 형식을 읽지 못한 원격 행은
/// 건너뛰고, 그 id 의 기기 행으로 덮어쓰지 않는다.
/// 보관함을 맞춘 다음 [photos] 가 있으면 사진 색인과 세트 저장 기록도 맞춘다. 사진 쪽이 실패해도
/// 보관함 동기화 결과는 그대로다.
/// 마지막 동기화 시각은 [stateFile] 에 `{ "lastSyncAt": ISO 8601 UTC }` 로 둔다 (표시용).
class SyncService extends ChangeNotifier {
  SyncService({
    required this.library,
    required this.remote,
    required this.log,
    required this.stateFile,
    this.photos,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LibraryStore library;
  final RemoteLibrary remote;
  final CameraLog log;
  final File stateFile;
  final PhotoSync? photos;
  final DateTime Function() _clock;

  DateTime? _lastSyncAt;
  var _syncing = false;

  DateTime? get lastSyncAt => _lastSyncAt;
  bool get syncing => _syncing;

  /// 파일이 없거나 형식이 맞지 않으면 동기화한 적 없는 것으로 본다.
  Future<void> loadState() async {
    _lastSyncAt = null;
    if (await stateFile.exists()) {
      try {
        if (jsonDecode(await stateFile.readAsString()) case {
          'lastSyncAt': final String text,
        }) {
          _lastSyncAt = parseUtc(text);
        }
      } on FormatException {
        _lastSyncAt = null;
      }
    }
    notifyListeners();
  }

  /// 성공하면 true. 원격에 닿지 못하면 기기 데이터와 동기화 시각을 그대로 두고 false.
  Future<bool> sync() async {
    if (_syncing) return false;
    _syncing = true;
    notifyListeners();
    try {
      final startedAt = _clock().toUtc();
      final changes = await remote.fetchAll();
      final recipes = _parse(changes.recipes, Recipe.fromJson, (r) => r.id);
      final loadouts = _parse(changes.loadouts, Loadout.fromJson, (l) => l.id);
      final merged = await library.mergeRemote(
        recipes: recipes.rows,
        loadouts: loadouts.rows,
      );

      final upRecipes = [
        for (final r in library.allRecipes)
          if (recipes.isNewerLocally(r.id, r.updatedAt)) r,
      ];
      final upLoadouts = [
        for (final l in library.allLoadouts)
          if (loadouts.isNewerLocally(l.id, l.updatedAt)) l,
      ];
      await remote.upsert(recipes: upRecipes, loadouts: upLoadouts);

      _lastSyncAt = startedAt;
      await writeJsonAtomically(stateFile, {
        'lastSyncAt': startedAt.toIso8601String(),
      });
      log.add(
        '동기화: 다운로드 ${changes.recipes.length + changes.loadouts.length}, '
        '병합 $merged, 업로드 ${upRecipes.length + upLoadouts.length}, '
        '건너뜀 ${recipes.skipped + loadouts.skipped}',
      );
      await _syncPhotos();
      return true;
    } on Exception catch (e) {
      log.add('동기화 실패: $e');
      return false;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _syncPhotos() async {
    try {
      await photos?.sync();
    } on Exception catch (e) {
      log.add('사진 동기화 실패: $e');
    }
  }

  static _Parsed<T> _parse<T>(
    List<Object?> bodies,
    T Function(Object?) fromJson,
    String Function(T) idOf,
  ) {
    final parsed = _Parsed<T>();
    for (final body in bodies) {
      try {
        final row = fromJson(body);
        parsed.rows.add(row);
        parsed.remoteUpdatedAt[idOf(row)] = switch (body) {
          {'updatedAt': final String text} => parseUtc(text),
          _ => null,
        };
      } on FormatException {
        parsed.skipped++;
        if (body case {'id': final String id}) parsed.unreadable.add(id);
      }
    }
    return parsed;
  }
}

/// 원격 행을 읽은 결과.
class _Parsed<T> {
  final rows = <T>[];

  /// 읽은 원격 행의 id → updatedAt.
  final remoteUpdatedAt = <String, DateTime?>{};

  /// 형식을 읽지 못한 원격 행의 id. 기기 행으로 덮어쓰지 않는다.
  final unreadable = <String>{};
  var skipped = 0;

  /// 기기 행을 올려야 하는지: 원격에 없거나, 원격보다 늦게 고쳤을 때.
  bool isNewerLocally(String id, DateTime localUpdatedAt) {
    if (unreadable.contains(id)) return false;
    if (!remoteUpdatedAt.containsKey(id)) return true;
    final remote = remoteUpdatedAt[id];
    return remote == null || localUpdatedAt.isAfter(remote);
  }
}
