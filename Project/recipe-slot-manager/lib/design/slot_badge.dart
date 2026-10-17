import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/design/tokens.dart';

/// 커스텀 슬롯 번호(C1–C7) 표시. [active] 면 강조색 테두리.
class SlotBadge extends StatelessWidget {
  const SlotBadge({super.key, required this.slot, this.active = false});

  final int slot;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(
          color: active ? AppColors.accent : AppColors.line,
          width: active ? 2 : 1,
        ),
      ),
      child: Text(
        'C$slot',
        style: AppType.numeric.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? AppColors.accent : AppColors.textMuted,
        ),
      ),
    );
  }
}
