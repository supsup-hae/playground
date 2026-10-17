import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/library/loadout.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';
import 'package:recipe_slot_manager/sync/remote_library.dart';
import 'package:recipe_slot_manager/util/atomic_json.dart';

/// 기기 보관함과 원격 보관함을 맞춘다.
///
/// 마지막 동기화 이후 바뀐 기기 행을 올리고, 그 이후 바뀐 원격 행을 받아
/// id 별로 updatedAt 이 늦은 쪽을 남긴다 ([LibraryStore.mergeRemote]).
/// 마지막 동기화 시각은 [stateFile] 에 `{ "lastSyncAt": ISO 8601 UTC }` 로 둔다.
class SyncService extends ChangeNotifier {
  SyncService({
    required this.library,
    required this.remote,
    required this.log,
    required this.stateFile,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LibraryStore library;
  final RemoteLibrary remote;
  final CameraLog log;
  final File stateFile;
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
      final since = _lastSyncAt;
      final startedAt = _clock().toUtc();
      bool changedSince(DateTime updatedAt) =>
          since == null || updatedAt.isAfter(since);
      final recipes = library.allRecipes
          .where((r) => changedSince(r.updatedAt))
          .toList();
      final loadouts = library.allLoadouts
          .where((l) => changedSince(l.updatedAt))
          .toList();
      await remote.upsert(recipes: recipes, loadouts: loadouts);

      final changes = await remote.fetchSince(since);
      var skipped = 0;
      List<T> parse<T>(List<Object?> rows, T Function(Object?) fromJson) {
        final parsed = <T>[];
        for (final row in rows) {
          try {
            parsed.add(fromJson(row));
          } on FormatException {
            skipped++;
          }
        }
        return parsed;
      }

      final merged = await library.mergeRemote(
        recipes: parse(changes.recipes, Recipe.fromJson),
        loadouts: parse(changes.loadouts, Loadout.fromJson),
      );

      _lastSyncAt = startedAt;
      await writeJsonAtomically(stateFile, {
        'lastSyncAt': startedAt.toIso8601String(),
      });
      log.add(
        '동기화: 올림 ${recipes.length + loadouts.length}, '
        '받음 ${changes.recipes.length + changes.loadouts.length}, '
        '바뀜 $merged, 건너뜀 $skipped',
      );
      return true;
    } on Exception catch (e) {
      log.add('동기화 실패: $e');
      return false;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }
}
