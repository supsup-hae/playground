import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/design/tokens.dart';

/// 비교 화면의 한 줄. 값이 바뀌면 이전 값(취소선)과 이후 값(강조색)을 함께, 같으면 값 하나만 보인다.
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

  @override
  Widget build(BuildContext context) {
    final changed = before != after;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: changed ? AppColors.text : AppColors.textMuted,
              ),
            ),
          ),
          if (changed) ...[
            Text(
              before,
              style: AppType.numeric.copyWith(
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
            Text(
              after,
              style: AppType.numeric.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else
            Text(
              after,
              style: AppType.numeric.copyWith(color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}
