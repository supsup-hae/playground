import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:recipe_slot_manager/design/tokens.dart';

/// 카메라 모드 다이얼처럼 정해진 선택지 중 하나를 고르는 가로 세그먼트.
/// 누르거나 ←→ 키로 옮기고, 바뀐 값은 [onChanged] 로 알린다.
class KnobSelector<T> extends StatefulWidget {
  const KnobSelector({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;

  /// (값, 보이는 이름) 목록.
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  State<KnobSelector<T>> createState() => _KnobSelectorState<T>();
}

class _KnobSelectorState<T> extends State<KnobSelector<T>> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _select(T value) {
    if (value != widget.value) widget.onChanged(value);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final index = widget.options.indexWhere((o) => o.$1 == widget.value);
    final next = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight => index + 1,
      LogicalKeyboardKey.arrowLeft => index - 1,
      _ => null,
    };
    if (next == null) return KeyEventResult.ignored;
    if (next >= 0 && next < widget.options.length) {
      _select(widget.options[next].$1);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label.toUpperCase(), style: AppType.label),
        const SizedBox(height: AppSpacing.xs),
        Focus(
          focusNode: _focus,
          includeSemantics: false,
          onKeyEvent: _onKey,
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (value, name) in widget.options)
                _Segment(
                  name: name,
                  selected: value == widget.value,
                  onTap: () {
                    _focus.requestFocus();
                    _select(value);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceRaised : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.line,
            ),
          ),
          child: Text(
            name,
            style: TextStyle(
              color: selected ? AppColors.accent : AppColors.text,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
