import 'package:flutter/widgets.dart';

/// 카메라 다이얼풍 어두운 테마의 색. 강조색(다이얼 주황)은 선택·바뀐 값·바늘에만 쓴다.
abstract final class AppColors {
  static const background = Color(0xFF0F1012);
  static const surface = Color(0xFF17191C);
  static const surfaceRaised = Color(0xFF1F2226);
  static const line = Color(0xFF2A2D31);
  static const text = Color(0xFFECE9E4);
  static const textMuted = Color(0xFF9A9690);
  static const accent = Color(0xFFF08A24);
  static const danger = Color(0xFFE5484D);
  static const success = Color(0xFF3FB27F);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppRadius {
  static const sm = 4.0;
  static const md = 8.0;
  static const pill = 999.0;
}

abstract final class AppType {
  /// 눈금·값처럼 숫자가 바뀌어도 폭이 흔들리지 않아야 하는 글자.
  static const numeric = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.text,
  );

  /// 카메라 메뉴처럼 작고 자간이 넓은 항목 이름.
  static const label = TextStyle(
    fontSize: 11,
    letterSpacing: 0.8,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
  );
}
