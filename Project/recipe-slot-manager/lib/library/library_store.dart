import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/library/loadout.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';
import 'package:recipe_slot_manager/util/atomic_json.dart';

/// 레시피와 묶음을 기기의 JSON 파일(`recipes.json`, `loadouts.json`)에 저장한다.
///
/// 삭제는 삭제 시각만 기록하고 행은 남겨, 동기화 때 다른 기기에도 삭제가 전해지게 한다.
class LibraryStore extends ChangeNotifier {
  LibraryStore(this.directory, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Directory directory;
  final DateTime Function() _clock;
  final _recipes = <String, Recipe>{};
  final _loadouts = <String, Loadout>{};

  File get _recipeFile => File(p.join(directory.path, 'recipes.json'));
  File get _loadoutFile => File(p.join(directory.path, 'loadouts.json'));

  /// 삭제하지 않은 레시피, 이름순.
  List<Recipe> get recipes =>
      _recipes.values.where((r) => !r.isDeleted).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// 삭제하지 않은 묶음, 이름순.
  List<Loadout> get loadouts =>
      _loadouts.values.where((l) => !l.isDeleted).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// 삭제 표시를 포함한 전체. 동기화가 쓴다.
  Iterable<Recipe> get allRecipes => _recipes.values;
  Iterable<Loadout> get allLoadouts => _loadouts.values;

  Recipe? recipeById(String? id) => switch (_recipes[id]) {
    final recipe? when !recipe.isDeleted => recipe,
    _ => null,
  };

  /// 묶음의 슬롯 1–7 에 해당하는 레시피. 비운 칸, 없거나 삭제된 레시피는 null.
  List<Recipe?> slotRecipes(Loadout loadout) => [
    for (final id in loadout.slots) recipeById(id),
  ];

  /// 파일이 없으면 빈 보관함. 형식이 맞지 않으면 [FormatException].
  Future<void> load() async {
    final recipes = await _read(_recipeFile, 'recipes', Recipe.fromJson);
    final loadouts = await _read(_loadoutFile, 'loadouts', Loadout.fromJson);
    _recipes
      ..clear()
      ..addAll({for (final r in recipes) r.id: r});
    _loadouts
      ..clear()
      ..addAll({for (final l in loadouts) l.id: l});
    notifyListeners();
  }

  Future<Recipe> saveRecipe(Recipe recipe) async {
    final stamped = recipe.copyWith(updatedAt: _clock().toUtc());
    _recipes[stamped.id] = stamped;
    await _writeRecipes();
    return stamped;
  }

  Future<void> deleteRecipe(String id) async {
    final recipe = _recipes[id];
    if (recipe == null) return;
    _recipes[id] = recipe.markDeleted(_clock().toUtc());
    await _writeRecipes();
  }

  Future<Loadout> saveLoadout(Loadout loadout) async {
    final stamped = loadout.copyWith(updatedAt: _clock().toUtc());
    _loadouts[stamped.id] = stamped;
    await _writeLoadouts();
    return stamped;
  }

  Future<void> deleteLoadout(String id) async {
    final loadout = _loadouts[id];
    if (loadout == null) return;
    _loadouts[id] = loadout.markDeleted(_clock().toUtc());
    await _writeLoadouts();
  }

  /// 원격 행을 합친다. id 별로 updatedAt 이 늦은 쪽을 남기고, 바뀐 행 수를 돌려준다.
  /// 원격 행의 시각은 그대로 둔다.
  Future<int> mergeRemote({
    required List<Recipe> recipes,
    required List<Loadout> loadouts,
  }) async {
    var changed = 0;
    for (final remote in recipes) {
      final local = _recipes[remote.id];
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        _recipes[remote.id] = remote;
        changed++;
      }
    }
    for (final remote in loadouts) {
      final local = _loadouts[remote.id];
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        _loadouts[remote.id] = remote;
        changed++;
      }
    }
    if (changed > 0) {
      await writeJsonAtomically(_recipeFile, _recipeJson());
      await writeJsonAtomically(_loadoutFile, _loadoutJson());
      notifyListeners();
    }
    return changed;
  }

  Future<void> _writeRecipes() async {
    await writeJsonAtomically(_recipeFile, _recipeJson());
    notifyListeners();
  }

  Future<void> _writeLoadouts() async {
    await writeJsonAtomically(_loadoutFile, _loadoutJson());
    notifyListeners();
  }

  Map<String, Object> _recipeJson() => {
    'recipes': [for (final r in _recipes.values) r.toJson()],
  };

  Map<String, Object> _loadoutJson() => {
    'loadouts': [for (final l in _loadouts.values) l.toJson()],
  };

  static Future<List<T>> _read<T>(
    File file,
    String key,
    T Function(Object?) parse,
  ) async {
    if (!await file.exists()) return [];
    final json = jsonDecode(await file.readAsString());
    if (json case final Map<String, dynamic> map) {
      if (map[key] case final List<dynamic> rows) {
        return [for (final row in rows) parse(row)];
      }
    }
    throw FormatException('$key 파일 형식이 맞지 않다', file.path);
  }
}
