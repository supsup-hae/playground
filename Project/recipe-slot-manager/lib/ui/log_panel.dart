import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/design/tokens.dart';

/// 화면 하단의 작업 로그. 최근 30줄을 새것부터 보인다.
class LogPanel extends StatelessWidget {
  const LogPanel({super.key, required this.log});

  final CameraLog log;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) => Container(
        height: 140,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: ListView(
          children: [
            for (final (time, message) in log.entries.reversed.take(30))
              Text(
                '${time.toIso8601String().substring(11, 19)}  $message',
                style: AppType.numeric.copyWith(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
