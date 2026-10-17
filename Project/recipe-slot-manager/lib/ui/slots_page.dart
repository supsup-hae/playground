import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/camera/fuji_camera.dart';
import 'package:recipe_slot_manager/camera/prop_value.dart';
import 'package:recipe_slot_manager/camera/slot_backup_store.dart';
import 'package:recipe_slot_manager/camera/slot_snapshot.dart';
import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/ptp/ptp_transport.dart';

/// C1–C7의 원시 값을 표로 보여 주고, 값 수정·쓰기·백업 복원을 하는 확인용 화면.
class SlotsPage extends StatefulWidget {
  const SlotsPage({super.key, required this.camera, required this.backupStore});

  final FujiCamera camera;
  final SlotBackupStore backupStore;

  @override
  State<SlotsPage> createState() => _SlotsPageState();
}

class _SlotsPageState extends State<SlotsPage> {
  String? _model;
  List<SlotSnapshot> _slots = const [];

  /// 슬롯 번호 → (속성 코드 → 새 값). 아직 카메라에 쓰지 않은 수정.
  final _edits = <int, Map<int, Uint8List>>{};
  var _busy = false;

  FujiCamera get _camera => widget.camera;

  /// [action] 을 실행하고 실패를 로그에 남긴다. 쓰기 도중 실패하면 카메라 값이 표와
  /// 달라졌을 수 있으므로, [clearSlotsOnError] 이면 표를 비워 다시 읽게 한다.
  Future<void> _run(
    String label,
    Future<void> Function() action, {
    bool clearSlotsOnError = false,
  }) async {
    setState(() => _busy = true);
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
      if (failure != null) _camera.log.add('$label 실패: $failure');
      if (mounted) {
        setState(() {
          _busy = false;
          if (failure != null && clearSlotsOnError) _slots = const [];
        });
      }
    }
  }

  Future<void> _connect() => _run('연결', () async {
    final model = await _camera.connect();
    if (mounted) setState(() => _model = model);
  });

  Future<void> _readAll() => _run('읽기', _reload);

  Future<void> _reload() async {
    final slots = await _camera.readAllSlots();
    if (mounted) setState(() => _slots = slots);
  }

  /// 카메라에서 7슬롯을 새로 읽어 백업으로 남기고, 읽은 값을 돌려준다.
  Future<List<SlotSnapshot>> _backupFromCamera() async {
    final slots = await _camera.readAllSlots();
    final file = await widget.backupStore.save(_model ?? 'unknown', slots);
    _camera.log.add('백업 저장: ${file.uri.pathSegments.last}');
    return slots;
  }

  Future<void> _writeSlot(int slot) => _run('C$slot 쓰기', () async {
    final fresh = await _backupFromCamera();
    final current = fresh.firstWhere((s) => s.slot == slot);
    final target = current.copyWith(
      props: {...current.props, ...?_edits[slot]},
    );
    _logResult(await _camera.writeSlot(target, current: current));
    _edits.remove(slot);
    await _reload();
  }, clearSlotsOnError: true);

  Future<void> _restore() async {
    final List<File> files;
    try {
      files = await widget.backupStore.list();
    } on FileSystemException catch (e) {
      setState(() => _camera.log.add('복원 실패: 백업 목록 ${e.message}'));
      return;
    }
    if (!mounted) return;
    final file = await showDialog<File>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('복원할 백업'),
        children: [
          if (files.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('백업이 없다')),
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
      final backup = await widget.backupStore.load(file);
      if (backup.model != _model) {
        _camera.log.add('복원 취소: 백업 모델(${backup.model})이 연결된 카메라($_model)와 다르다');
        return;
      }
      await _backupFromCamera();
      (await _camera.restore(backup.slots)).forEach(_logResult);
      _edits.clear();
      await _reload();
    }, clearSlotsOnError: true);
  }

  void _logResult(SlotWriteResult result) {
    for (final warning in result.warnings) {
      _camera.log.add('C${result.slot} $warning');
    }
    for (final code in result.mismatched) {
      _camera.log.add('C${result.slot} ${propLabel(code)}: 다시 읽은 값이 다르다');
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Slot Manager'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: Text(_model ?? '카메라 없음')),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _toolbar(),
          Expanded(
            child: _slots.isEmpty
                ? const Center(child: Text('연결한 뒤 7슬롯을 읽는다'))
                : _table(),
          ),
          _logPanel(),
        ],
      ),
    );
  }

  Widget _toolbar() {
    final enabled = !_busy;
    final connected = _model != null;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton(
            onPressed: enabled && !connected ? _connect : null,
            child: const Text('연결'),
          ),
          OutlinedButton(
            onPressed: enabled && connected ? _readAll : null,
            child: const Text('7슬롯 읽기'),
          ),
          OutlinedButton(
            onPressed: enabled && connected ? _restore : null,
            child: const Text('백업에서 복원'),
          ),
          for (final slot in _slots.where(
            (s) => _edits[s.slot]?.isNotEmpty ?? false,
          ))
            FilledButton.tonal(
              onPressed: enabled ? () => _writeSlot(slot.slot) : null,
              child: Text('C${slot.slot} 쓰기'),
            ),
          if (_busy)
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
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
                      onTap: _busy ? null : () => _editCell(slot, code),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _logPanel() {
    final entries = _camera.log.entries.reversed.take(30);
    return Container(
      height: 160,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(8),
      child: ListView(
        children: [
          for (final (time, message) in entries)
            Text(
              '${time.toIso8601String().substring(11, 19)}  $message',
              style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
            ),
        ],
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
      setState(() => _error = '범위 $_range 의 정수를 입력한다');
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
