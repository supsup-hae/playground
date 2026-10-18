import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/design/tokens.dart';

/// 비교 화면의 한 줄. 값이 바뀌면 이전 값(취소선)과 이후 값(강조색)을 함께, 같으면 값 하나만 보인다.
/// 폭이 모자라면 이름과 값을 말줄임으로 줄인다.
class ChangeRow extends StatelessWidget {
  const ChangeRow({
    super.key,
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final String before;
  final String after;

  /// 값 하나가 줄 폭에서 차지할 수 있는 최대 비율. 넘는 값은 말줄임으로 줄인다.
  static const _valueShare = 0.3;

  @override
  Widget build(BuildContext context) {
    final changed = before != after;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: LayoutBuilder(
        builder: (context, constraints) {
          Widget value(String text, TextStyle style) => ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * _valueShare,
            ),
            child: Text(text, overflow: TextOverflow.ellipsis, style: style),
          );
          return Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: changed ? AppColors.text : AppColors.textMuted,
                  ),
                ),
              ),
              if (changed) ...[
                value(
                  before,
                  AppType.numeric.copyWith(
                    color: AppColors.textMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                value(
                  after,
                  AppType.numeric.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else
                value(
                  after,
                  AppType.numeric.copyWith(color: AppColors.textMuted),
                ),
            ],
          );
        },
      ),
    );
  }
}
