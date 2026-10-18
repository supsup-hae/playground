import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/design/tokens.dart';

/// 화면 하단의 작업 로그. 최근 30줄을 새것부터 보인다.
///
/// [compact] 면 마지막 한 줄만 보이다가 누르면 펼친다.
class LogPanel extends StatefulWidget {
  const LogPanel({super.key, required this.log, this.compact = false});

  final CameraLog log;
  final bool compact;

  @override
  State<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<LogPanel> {
  static const _expandedHeight = 140.0;

  /// 접힌 상태도 손가락으로 누를 수 있는 최소 크기를 지킨다.
  static const _foldedHeight = kMinInteractiveDimension;

  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final folded = widget.compact && !_expanded;
    return ListenableBuilder(
      listenable: widget.log,
      builder: (context, _) {
        final lines = [
          for (final (time, message) in widget.log.entries.reversed.take(
            folded ? 1 : 30,
          ))
            Text(
              '${time.toIso8601String().substring(11, 19)}  $message',
              maxLines: folded ? 1 : null,
              overflow: folded ? TextOverflow.ellipsis : null,
              style: AppType.numeric.copyWith(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
        ];
        final panel = Container(
          key: const ValueKey('log-panel'),
          height: folded ? _foldedHeight : _expandedHeight,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: folded
              ? Align(alignment: Alignment.centerLeft, child: lines.firstOrNull)
              : ListView(children: lines),
        );
        if (!widget.compact) return panel;
        return Semantics(
          button: true,
          label: _expanded ? '로그 접기' : '로그 펼치기',
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: panel,
          ),
        );
      },
    );
  }
}
