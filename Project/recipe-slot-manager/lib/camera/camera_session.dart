import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/camera/fuji_camera.dart';
import 'package:recipe_slot_manager/camera/slot_backup_store.dart';
import 'package:recipe_slot_manager/camera/slot_snapshot.dart';
import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/ptp/ptp_transport.dart';

/// 여러 화면이 함께 쓰는 카메라 연결 상태. 한 번에 작업 하나만 돌리고([busy]),
/// 실패는 로그에 남긴다.
class CameraSession extends ChangeNotifier {
  CameraSession(this.camera, this.backups);

  final FujiCamera camera;
  final SlotBackupStore backups;

  String? _model;
  var _busy = false;

  /// 연결된 카메라 모델 이름. 연결 전에는 null.
  String? get model => _model;
  bool get connected => _model != null;
  bool get busy => _busy;
  CameraLog get log => camera.log;

  /// [action] 을 실행한다. 카메라·백업 파일·형식 오류는 `'<label> 실패: …'` 로 로그에 남기고
  /// 그 문구를 돌려준다. 성공하면 null.
  Future<String?> run(String label, Future<void> Function() action) async {
    _busy = true;
    notifyListeners();
    String? failure;
    try {
      await action();
    } on PtpTransportException catch (e) {
      failure = e.message;
    } on SlotWriteException catch (e) {
      failure = e.message;
    } on FileSystemException catch (e) {
      failure = '백업 파일 ${e.message}';
    } on FormatException catch (e) {
      failure = '형식 오류: ${e.message}';
    } finally {
      _busy = false;
      if (failure != null) log.add('$label 실패: $failure');
      notifyListeners();
    }
    return failure;
  }

  Future<void> connect() => run('연결', () async {
    _model = await camera.connect();
  });

  /// 카메라에서 7슬롯을 새로 읽어 백업으로 남기고, 읽은 값을 돌려준다.
  /// 쓰기·복원 직전에 부른다.
  Future<List<SlotSnapshot>> backupFromCamera() async {
    final slots = await camera.readAllSlots();
    final file = await backups.save(_model ?? 'unknown', slots);
    log.add('백업 저장: ${file.uri.pathSegments.last}');
    return slots;
  }

  void logWriteResult(SlotWriteResult result) {
    for (final warning in result.warnings) {
      log.add('C${result.slot} $warning');
    }
    for (final code in result.mismatched) {
      log.add('C${result.slot} ${propLabel(code)}: 다시 읽은 값이 다르다');
    }
  }
}
