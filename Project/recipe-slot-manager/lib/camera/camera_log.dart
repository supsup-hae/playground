/// 카메라 작업 기록. 화면 하단에 그대로 보여 준다.
class CameraLog {
  final _entries = <(DateTime, String)>[];

  List<(DateTime, String)> get entries => List.unmodifiable(_entries);

  void add(String message) => _entries.add((DateTime.now(), message));
}
