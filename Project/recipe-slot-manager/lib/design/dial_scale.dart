import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/util/step_value.dart';

/// 카메라 다이얼처럼 가운데 바늘 아래로 눈금이 움직이는 숫자 입력.
///
/// 눈금을 끌거나, 눈금을 누르거나, 스크롤하거나, ←→ 키로 [step] 단위로 움직인다.
/// 값은 부모가 들고 있고, 바뀐 값은 [onChanged] 로 알린다.
class DialScale extends StatefulWidget {
  const DialScale({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.format = formatSigned,
  });

  /// 눈금 한 칸의 너비(논리 픽셀).
  static const tickSpacing = 12.0;
  static const _scaleHeight = 40.0;

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final String Function(double) format;

  @override
  State<DialScale> createState() => _DialScaleState();
}

class _DialScaleState extends State<DialScale> {
  final _focus = FocusNode();
  var _focused = false;
  double _dragStartValue = 0;
  double _dragDx = 0;
  double? _lastDragValue;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  double _snap(double value) =>
      snapToStep(value, min: widget.min, max: widget.max, step: widget.step);

  void _emit(double value) {
    final snapped = _snap(value);
    if (snapped != widget.value) widget.onChanged(snapped);
  }

  void _nudge(int steps) => _emit(widget.value + steps * widget.step);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.arrowUp:
        _nudge(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowDown:
        _nudge(-1);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _onDragStart(DragStartDetails details) {
    _dragStartValue = widget.value;
    _dragDx = 0;
    _lastDragValue = null;
  }

  // 눈금을 왼쪽으로 끌면 바늘 아래로 오른쪽(큰 값) 눈금이 온다.
  void _onDragUpdate(DragUpdateDetails details) {
    _dragDx += details.delta.dx;
    final value = _snap(
      _dragStartValue - _dragDx / DialScale.tickSpacing * widget.step,
    );
    if (value != _lastDragValue && value != widget.value) {
      _lastDragValue = value;
      widget.onChanged(value);
    }
  }

  void _onTapUp(TapUpDetails details, double width) {
    _focus.requestFocus();
    final steps =
        ((details.localPosition.dx - width / 2) / DialScale.tickSpacing)
            .round();
    if (steps != 0) _nudge(steps);
  }

  void _onScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
      _nudge(event.scrollDelta.dy < 0 ? 1 : -1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    return Semantics(
      container: true,
      slider: true,
      label: widget.label,
      value: widget.format(value),
      increasedValue: widget.format(_snap(value + widget.step)),
      decreasedValue: widget.format(_snap(value - widget.step)),
      onIncrease: () => _nudge(1),
      onDecrease: () => _nudge(-1),
      child: ExcludeSemantics(
        child: Focus(
          focusNode: _focus,
          includeSemantics: false,
          onKeyEvent: _onKey,
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label.toUpperCase(),
                      style: AppType.label,
                    ),
                  ),
                  Text(
                    widget.format(value),
                    style: AppType.numeric.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              LayoutBuilder(
                builder: (context, constraints) => Listener(
                  onPointerSignal: _onScroll,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    dragStartBehavior: DragStartBehavior.down,
                    onHorizontalDragStart: _onDragStart,
                    onHorizontalDragUpdate: _onDragUpdate,
                    onTapUp: (d) => _onTapUp(d, constraints.maxWidth),
                    child: Container(
                      height: DialScale._scaleHeight,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: _focused ? AppColors.accent : AppColors.line,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _TickPainter(
                            value: value,
                            min: widget.min,
                            max: widget.max,
                            step: widget.step,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
  });

  final double value;
  final double min;
  final double max;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    final visibleSteps = (center / DialScale.tickSpacing).ceil() + 1;
    final valueStep = ((value - min) / step).round();
    final lastStep = ((max - min) / step).round();
    // 간격이 1보다 작으면 정수마다, 크면 다섯 칸마다 긴 눈금을 그린다.
    final majorEvery = step < 1 ? (1 / step).round() : 5;
    final tick = Paint()..strokeWidth = 1;

    for (var k = valueStep - visibleSteps; k <= valueStep + visibleSteps; k++) {
      if (k < 0 || k > lastStep) continue;
      final x = center + (k - valueStep) * DialScale.tickSpacing;
      final tickValue = min + k * step;
      final major = (tickValue / step).round() % majorEvery == 0;
      tick.color = major ? AppColors.textMuted : AppColors.line;
      final height = major ? size.height * 0.5 : size.height * 0.28;
      canvas.drawLine(
        Offset(x, size.height - height),
        Offset(x, size.height),
        tick,
      );
      if (tickValue.abs() < step / 2) {
        canvas.drawCircle(
          Offset(x, size.height * 0.2),
          2,
          Paint()..color = AppColors.textMuted,
        );
      }
    }

    final needle = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2;
    canvas.drawLine(Offset(center, 0), Offset(center, size.height), needle);
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.value != value ||
      old.min != min ||
      old.max != max ||
      old.step != step;
}
