import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/camera/camera_session.dart';
import 'package:recipe_slot_manager/camera/slot_snapshot.dart';
import 'package:recipe_slot_manager/design/change_row.dart';
import 'package:recipe_slot_manager/design/slot_badge.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/library/loadout.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';
import 'package:recipe_slot_manager/recipe/recipe_codec.dart';
import 'package:recipe_slot_manager/recipe/recipe_diff.dart';
import 'package:recipe_slot_manager/ui/app_shell.dart';
import 'package:recipe_slot_manager/ui/log_panel.dart';

/// 묶음을 카메라의 현재 7슬롯과 비교해 바뀌는 값을 보이고, 한 번에 쓴다.
class ApplyLoadoutPage extends StatefulWidget {
  const ApplyLoadoutPage({
    super.key,
    required this.session,
    required this.library,
    required this.loadout,
  });

  final CameraSession session;
  final LibraryStore library;
  final Loadout loadout;

  /// PRD 성공 기준: 7슬롯 전체 쓰기 10초 이내.
  static const targetDuration = Duration(seconds: 10);

  @override
  State<ApplyLoadoutPage> createState() => _ApplyLoadoutPageState();
}

class _ApplyLoadoutPageState extends State<ApplyLoadoutPage> {
  List<SlotSnapshot>? _current;
  Duration? _elapsed;

  CameraSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    if (_session.connected) _read();
  }

  Future<void> _connectAndRead() async {
    await _session.connect();
    if (_session.connected) await _read();
  }

  Future<void> _read() => _session.run('불러오기', () async {
    final slots = await _session.camera.readAllSlots();
    if (mounted) setState(() => _current = slots);
  });

  Future<void> _write() async {
    final failure = await _session.run('C1–C7에 저장', () async {
      final fresh = await _session.backupFromCamera();
      final recipes = widget.library.slotRecipes(widget.loadout);
      final targets = [
        for (var i = 0; i < fresh.length; i++)
          switch (recipes[i]) {
            final recipe? => encodeValues(
              recipe.name,
              recipe.values,
              base: fresh[i],
            ),
            null => fresh[i],
          },
      ];
      final watch = Stopwatch()..start();
      final results = await _session.camera.writeSlots(targets, current: fresh);
      watch.stop();
      results.forEach(_session.logWriteResult);
      final after = await _session.camera.readAllSlots();
      if (mounted) {
        setState(() {
          _elapsed = watch.elapsed;
          _current = after;
        });
      }
    });
    // 쓰기가 중간에 멈추면 비교 화면이 카메라와 다를 수 있으므로 비우고 다시 읽게 한다.
    if (failure != null && mounted) setState(() => _current = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.loadout.name} 비교·저장')),
      body: Column(
        children: [
          CameraBar(session: _session),
          const Divider(height: 1),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([_session, widget.library]),
              builder: (context, _) => _body(),
            ),
          ),
          LogPanel(log: _session.log),
        ],
      ),
    );
  }

  Widget _body() {
    final current = _current;
    if (!_session.connected) {
      return Center(
        child: FilledButton(
          onPressed: _session.busy ? null : _connectAndRead,
          child: const Text('카메라 연결 후 불러오기'),
        ),
      );
    }
    if (current == null) {
      return Center(
        child: _session.busy
            ? const CircularProgressIndicator()
            : OutlinedButton(onPressed: _read, child: const Text('다시 불러오기')),
      );
    }
    final recipes = widget.library.slotRecipes(widget.loadout);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (var i = 0; i < current.length; i++)
                _SlotCard(current: current[i], recipe: recipes[i]),
            ],
          ),
        ),
        _footer(),
      ],
    );
  }

  Widget _footer() {
    final elapsed = _elapsed;
    final slow = elapsed != null && elapsed > ApplyLoadoutPage.targetDuration;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '실기기 미확인: 저장하기 전에 C1–C7을 자동으로 백업합니다',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          if (elapsed != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Text(
                '${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)}초',
                style: AppType.numeric.copyWith(
                  color: slow ? AppColors.danger : AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          FilledButton(
            onPressed: _session.busy ? null : _write,
            child: const Text('C1–C7에 저장'),
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.current, required this.recipe});

  final SlotSnapshot current;
  final Recipe? recipe;

  @override
  Widget build(BuildContext context) {
    final recipe = this.recipe;
    final changes = recipe == null
        ? const <FieldChange>[]
        : diffValues(decodeSlot(current), recipe.values);
    final renamed = recipe != null && recipe.name != current.name;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SlotBadge(
                  slot: current.slot,
                  active: renamed || changes.isNotEmpty,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(current.name)),
                if (recipe == null)
                  const Text(
                    '변경 없음',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
              ],
            ),
            if (recipe != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ChangeRow(label: '이름', before: current.name, after: recipe.name),
              for (final change in changes)
                ChangeRow(
                  label: change.field.label,
                  before: change.before,
                  after: change.after,
                ),
              if (!renamed && changes.isEmpty)
                const Text(
                  '변경되는 값 없음',
                  style: TextStyle(color: AppColors.textMuted),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
