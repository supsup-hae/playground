import 'dart:io';

import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/library/loadout.dart';
import 'package:recipe_slot_manager/photo/locator.dart';
import 'package:recipe_slot_manager/photo/place_log.dart';
import 'package:recipe_slot_manager/photo/place_log_store.dart';
import 'package:recipe_slot_manager/photo/place_resolver.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';

/// 세트를 카메라에 저장한 뒤 그때의 위치와 세트를 기록한다. 기록이 실패해도 저장에는 영향이 없도록
/// 어떤 실패도 밖으로 던지지 않고 로그에 남긴다.
class PlaceLogger {
  PlaceLogger({
    required this.store,
    required this.locator,
    required this.log,
    this.resolver,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PlaceLogStore store;

  /// 위치를 받을 수 없는 기기(macOS)는 null.
  final Locator? locator;
  final CameraLog log;

  /// 기록한 좌표의 장소 이름을 묻는다.
  final PlaceResolver? resolver;
  final DateTime Function() _clock;

  /// 위치 권한을 요청한다. 결과와 상관없이 저장은 이어서 한다.
  Future<void> prepare() async {
    await locator?.requestAccess();
  }

  /// [slots] 는 C1–C7 순서로 넣은 레시피 이름(그대로 둔 슬롯은 null).
  Future<void> record({
    required Loadout loadout,
    required List<String?> slots,
    String? model,
  }) async {
    LocationFix? fix;
    String? missingReason;
    if (locator case final locator?) {
      try {
        fix = await locator.current();
      } on LocateException catch (e) {
        missingReason = e.message;
      }
    } else {
      missingReason = '이 기기에서는 위치를 기록하지 않습니다';
    }
    final now = _clock();
    final entry = PlaceLog(
      id: newRecipeId(),
      loggedAt: now.toUtc(),
      utcOffset: now.timeZoneOffset,
      location: fix?.point,
      accuracy: fix?.accuracy,
      loadoutId: loadout.id,
      loadoutName: loadout.name,
      slots: slots,
      model: model,
      missingReason: missingReason,
    );
    try {
      await store.add(entry);
    } on FileSystemException catch (e) {
      log.add('저장 기록 실패: ${e.message}');
      return;
    }
    log.add('저장 기록: ${loadout.name} · ${_where(entry)}');
    if (entry.location == null) return;
    try {
      await resolver?.resolveMissing();
    } on FileSystemException catch (e) {
      log.add('장소 이름 저장 실패: ${e.message}');
    }
  }

  static String _where(PlaceLog entry) {
    final location = entry.location;
    if (location == null) return '위치 없음 (${entry.missingReason})';
    final accuracy = entry.accuracy;
    return '${location.latitude.toStringAsFixed(4)}, '
        '${location.longitude.toStringAsFixed(4)}'
        '${accuracy == null ? '' : ' (약 ${accuracy.round()} m)'}';
  }
}
