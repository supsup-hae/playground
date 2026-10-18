import 'package:flutter/widgets.dart';

/// 카메라 다이얼풍 어두운 테마의 색. 강조색(인덱스 빨강)은 선택·바뀐 값·바늘에만 쓴다.
/// 브랜드 기준은 `assets/brand/README.md`.
abstract final class AppColors {
  static const background = Color(0xFF0F1012);
  static const surface = Color(0xFF17191C);
  static const surfaceRaised = Color(0xFF1F2226);
  static const line = Color(0xFF2A2D31);
  static const text = Color(0xFFECE9E4);
  static const textMuted = Color(0xFF9A9690);

  /// 앱 화면용 빨강. 어두운 바탕·면 위에서 4.5:1 이 되도록 [brandRed] 보다 밝다.
  static const accent = Color(0xFFEA4A35);

  /// 경고·실패. 강조색이 빨강이므로 색상과 밝기 모두 강조색과 다른 앰버를 쓴다.
  static const danger = Color(0xFFF2A93B);
  static const success = Color(0xFF3FB27F);

  /// 아이콘·로고·인쇄용 브랜드 빨강. 작은 글자에는 쓰지 않는다.
  static const brandRed = Color(0xFFD7282F);

  /// 아이콘의 실버 상판.
  static const silver = Color(0xFFCFCBC4);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// 휴대폰 배치로 바꾸는 기준. 폭이 [compactWidth] 보다 좁거나 높이가 [compactHeight] 보다 낮으면
/// 아래 탭, 접힌 로그, 위아래로 쌓는 비교를 쓴다.
abstract final class AppBreakpoints {
  static const compactWidth = 600.0;
  static const compactHeight = 500.0;
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
