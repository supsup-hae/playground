import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/camera/slot_snapshot.dart';
import 'package:recipe_slot_manager/util/atomic_json.dart';

/// 7슬롯 백업을 JSON 파일로 저장하고 불러온다.
///
/// 파일 이름은 `slots-YYYYMMDD-HHmmss-SSS.json` (UTC)이고 내용은
/// `{ "model", "createdAt": ISO 8601 UTC, "slots": [SlotSnapshot…] }` 이다.
class SlotBackupStore {
  SlotBackupStore(this.directory, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Directory directory;
  final DateTime Function() _clock;

  Future<File> save(String model, List<SlotSnapshot> slots) async {
    final createdAt = _clock().toUtc();
    final file = File(
      p.join(directory.path, 'slots-${_stamp(createdAt)}.json'),
    );
    return writeJsonAtomically(file, {
      'model': model,
      'createdAt': createdAt.toIso8601String(),
      'slots': [for (final slot in slots) slot.toJson()],
    });
  }

  /// 최신 백업이 먼저 온다.
  Future<List<File>> list() async {
    if (!await directory.exists()) return [];
    final files = await directory
        .list()
        .where(
          (e) =>
              e is File &&
              p.basename(e.path).startsWith('slots-') &&
              e.path.endsWith('.json'),
        )
        .cast<File>()
        .toList();
    return files..sort((a, b) => b.path.compareTo(a.path));
  }

  /// 형식이 맞지 않거나 같은 슬롯이 두 번 있으면 [FormatException] 을 던진다.
  Future<SlotBackup> load(File file) async {
    final json = jsonDecode(await file.readAsString());
    if (json case {
      'model': final String model,
      'createdAt': final String createdAt,
      'slots': final List<dynamic> slots,
    }) {
      final snapshots = [for (final slot in slots) SlotSnapshot.fromJson(slot)];
      if (snapshots.map((s) => s.slot).toSet().length != snapshots.length) {
        throw FormatException('같은 C 번호 중복', file.path);
      }
      return SlotBackup(
        model: model,
        createdAt: DateTime.parse(createdAt),
        slots: snapshots,
      );
    }
    throw FormatException('백업 형식 오류', file.path);
  }

  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}'
        '-${t.millisecond.toString().padLeft(3, '0')}';
  }
}

final class SlotBackup {
  const SlotBackup({
    required this.model,
    required this.createdAt,
    required this.slots,
  });

  final String model;
  final DateTime createdAt;
  final List<SlotSnapshot> slots;
}
