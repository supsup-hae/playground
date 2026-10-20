import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/photo/place_log.dart';
import 'package:recipe_slot_manager/util/atomic_json.dart';
import 'package:recipe_slot_manager/util/serial_queue.dart';

/// 세트 저장 기록. 기기의 `place_logs.json` 에 저장한다.
class PlaceLogStore extends ChangeNotifier {
  PlaceLogStore(this.directory, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Directory directory;
  final DateTime Function() _clock;
  final _logs = <PlaceLog>[];
  final _writes = SerialQueue();

  File get _file => File(p.join(directory.path, 'place_logs.json'));

  /// 최신순.
  List<PlaceLog> get logs => List.unmodifiable(
    _logs.toList()..sort((a, b) => b.loggedAt.compareTo(a.loggedAt)),
  );

  /// 불러올 때 읽지 못해 옮겨 둔 파일 설명. 다음 [load] 에서 비워진다.
  List<String> get loadErrors => List.unmodifiable(_loadErrors);
  final _loadErrors = <String>[];

  /// 파일이 없으면 빈 기록. 형식이 맞지 않는 파일은 `place_logs.json.corrupt-<시각>` 으로 옮기고
  /// [loadErrors] 에 남긴 뒤 빈 기록으로 시작한다.
  Future<void> load() async {
    _loadErrors.clear();
    final read = await readJsonFile(
      _file,
      (json) => switch (json) {
        {'logs': final List<dynamic> logs} => logs.map(PlaceLog.fromJson),
        _ => throw FormatException('저장 기록 파일 형식 오류', json),
      }.toList(),
      now: _clock(),
      errors: _loadErrors,
    );
    _logs
      ..clear()
      ..addAll(read ?? const []);
    notifyListeners();
  }

  Future<void> add(PlaceLog log) async {
    _logs.add(log);
    await _writes.run(
      () => writeJsonAtomically(_file, {
        'logs': [for (final log in _logs) log.toJson()],
      }),
    );
    notifyListeners();
  }
}
