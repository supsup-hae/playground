import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/camera/camera_session.dart';
import 'package:recipe_slot_manager/camera/prop_value.dart';
import 'package:recipe_slot_manager/camera/slot_snapshot.dart';
import 'package:recipe_slot_manager/ptp/ptp_codes.dart';

/// C1–C7의 원시 값을 표로 보여 주고, 값 수정·쓰기·백업 복원을 하는 확인용 화면.
class SlotsPage extends StatefulWidget {
  const SlotsPage({super.key, required this.session});

  final CameraSession session;

  @override
  State<SlotsPage> createState() => _SlotsPageState();
}

class _SlotsPageState extends State<SlotsPage> {
  List<SlotSnapshot> _slots = const [];

  /// 슬롯 번호 → (속성 코드 → 새 값). 아직 카메라에 쓰지 않은 수정.
  final _edits = <int, Map<int, Uint8List>>{};

  CameraSession get _session => widget.session;

  /// 쓰기 도중 실패하면 카메라 값이 표와 달라졌을 수 있으므로,
  /// [clearSlotsOnError] 이면 표를 비워 다시 읽게 한다.
  Future<void> _run(
    String label,
    Future<void> Function() action, {
    bool clearSlotsOnError = false,
  }) async {
    final failure = await _session.run(label, action);
    if (mounted && failure != null && clearSlotsOnError) {
      setState(() => _slots = const []);
    }
  }

  Future<void> _readAll() => _run('불러오기', _reload);

  Future<void> _reload() async {
    final slots = await _session.camera.readAllSlots();
    if (mounted) setState(() => _slots = slots);
  }

  Future<void> _writeSlot(int slot) => _run('C$slot에 저장', () async {
    final fresh = await _session.backupFromCamera();
    final current = fresh.firstWhere((s) => s.slot == slot);
    final target = current.copyWith(
      props: {...current.props, ...?_edits[slot]},
    );
    _session.logWriteResult(
      await _session.camera.writeSlot(target, current: current),
    );
    _edits.remove(slot);
    await _reload();
  }, clearSlotsOnError: true);

  Future<void> _restore() async {
    final List<File> files;
    try {
      files = await _session.backups.list();
    } on FileSystemException catch (e) {
      _session.log.add('복원 실패: 백업 목록 ${e.message}');
      return;
    }
    if (!mounted) return;
    final file = await showDialog<File>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('복원할 백업'),
        children: [
          if (files.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('백업이 없습니다')),
          for (final file in files)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, file),
              child: Text(file.uri.pathSegments.last),
            ),
        ],
      ),
    );
    if (file == null) return;
    await _run('복원', () async {
      final backup = await _session.backups.load(file);
      if (backup.model != _session.model) {
        _session.log.add(
          '복원 취소: 백업 모델(${backup.model})이 연결된 카메라(${_session.model})와 다릅니다',
        );
        return;
      }
      await _session.backupFromCamera();
      (await _session.camera.restore(backup.slots))
          .forEach(_session.logWriteResult);
      _edits.clear();
      await _reload();
    }, clearSlotsOnError: true);
  }

  Future<void> _editCell(SlotSnapshot slot, int code) async {
    final current = _edits[slot.slot]?[code] ?? slot.props[code];
    final number = current == null ? null : decodePropValue(current);
    if (current == null || number == null) return;
    final bytes = await showDialog<Uint8List>(
      context: context,
      builder: (_) => _ValueDialog(
        title: 'C${slot.slot} ${propLabel(code)}',
        initial: number,
        length: current.length,
      ),
    );
    if (bytes == null || !mounted) return;
    setState(() => _edits.putIfAbsent(slot.slot, () => {})[code] = bytes);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _toolbar(),
          Expanded(
            child: _slots.isEmpty
                ? Center(
                    child: Text(
                      _session.connected
                          ? 'C1–C7을 불러오세요'
                          : '위에서 카메라를 연결한 뒤 C1–C7을 불러오세요',
                    ),
                  )
                : _table(),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    final enabled = _session.connected && !_session.busy;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: enabled ? _readAll : null,
            child: const Text('C1–C7 불러오기'),
          ),
          OutlinedButton(
            onPressed: enabled ? _restore : null,
            child: const Text('백업에서 복원'),
          ),
          for (final slot in _slots.where(
            (s) => _edits[s.slot]?.isNotEmpty ?? false,
          ))
            FilledButton.tonal(
              onPressed: enabled ? () => _writeSlot(slot.slot) : null,
              child: Text('C${slot.slot}에 저장'),
            ),
        ],
      ),
    );
  }

  Widget _table() {
    final edited = Theme.of(context).colorScheme.tertiaryContainer;
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          dataRowMinHeight: 32,
          dataRowMaxHeight: 32,
          columns: [
            const DataColumn(label: Text('속성')),
            for (final slot in _slots) DataColumn(label: Text('C${slot.slot}')),
          ],
          rows: [
            DataRow(
              cells: [
                const DataCell(Text('이름')),
                for (final slot in _slots) DataCell(Text(slot.name)),
              ],
            ),
            for (final code in FujiProp.presetProps)
              DataRow(
                cells: [
                  DataCell(Text(propLabel(code))),
                  for (final slot in _slots)
                    DataCell(
                      Container(
                        key: ValueKey('cell-${slot.slot}-${propLabel(code)}'),
                        color: _edits[slot.slot]?.containsKey(code) ?? false
                            ? edited
                            : null,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          displayPropValue(
                            _edits[slot.slot]?[code] ?? slot.props[code],
                          ),
                        ),
                      ),
                      onTap: _session.busy ? null : () => _editCell(slot, code),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 정수 하나를 입력받아 [length] 바이트 값으로 돌려준다. 범위를 벗어나면 닫지 않고 오류를 보인다.
class _ValueDialog extends StatefulWidget {
  const _ValueDialog({
    required this.title,
    required this.initial,
    required this.length,
  });

  final String title;
  final int initial;
  final int length;

  @override
  State<_ValueDialog> createState() => _ValueDialogState();
}

class _ValueDialogState extends State<_ValueDialog> {
  late var _text = '${widget.initial}';
  String? _error;

  String get _range =>
      widget.length == 2 ? '-32768–65535' : '-2147483648–4294967295';

  void _submit() {
    final value = int.tryParse(_text.trim());
    final bytes = value == null ? null : encodePropValue(value, widget.length);
    if (bytes == null) {
      setState(() => _error = '$_range 범위의 정수를 입력하세요');
      return;
    }
    Navigator.pop(context, bytes);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextFormField(
        initialValue: _text,
        onChanged: (v) => _text = v,
        onFieldSubmitted: (_) => _submit(),
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: InputDecoration(errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(onPressed: _submit, child: const Text('확인')),
      ],
    );
  }
}
