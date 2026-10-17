import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/design/app_theme.dart';
import 'package:recipe_slot_manager/design/change_row.dart';
import 'package:recipe_slot_manager/design/knob_selector.dart';
import 'package:recipe_slot_manager/design/slot_badge.dart';
import 'package:recipe_slot_manager/design/tokens.dart';

Widget _app(Widget child) => MaterialApp(
  theme: buildAppTheme(),
  home: Scaffold(body: child),
);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('글자색과 강조색은 바탕·면 대비 4.5:1 이상이다', () {
    for (final background in [AppColors.background, AppColors.surface]) {
      for (final foreground in [
        AppColors.text,
        AppColors.textMuted,
        AppColors.accent,
      ]) {
        expect(_contrast(foreground, background), greaterThanOrEqualTo(4.5));
      }
    }
  });

  group('KnobSelector', () {
    late String? changed;

    Future<void> pump(WidgetTester tester) async {
      changed = null;
      await tester.pumpWidget(
        _app(
          KnobSelector<String>(
            label: '그레인',
            options: const [('off', '끔'), ('weak', '약'), ('strong', '강')],
            value: 'weak',
            onChanged: (v) => changed = v,
          ),
        ),
      );
    }

    testWidgets('선택지를 누르면 그 값을 알린다', (tester) async {
      await pump(tester);

      await tester.tap(find.text('강'));

      expect(changed, 'strong');
    });

    testWidgets('←→ 키로 옆 선택지로 옮긴다', (tester) async {
      await pump(tester);
      await tester.tap(find.text('약'));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(changed, 'strong');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(changed, 'off');
    });

    testWidgets('선택된 칸은 선택 상태로 읽힌다', (tester) async {
      await pump(tester);

      expect(
        tester.getSemantics(find.text('약')),
        isSemantics(isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(find.text('강')),
        isSemantics(isButton: true, isSelected: false),
      );
    });
  });

  group('ChangeRow', () {
    testWidgets('값이 바뀌면 이전 값과 이후 값을 함께 보이고 이후 값을 강조한다', (tester) async {
      await tester.pumpWidget(
        _app(const ChangeRow(label: '하이라이트', before: '-1', after: '+0.5')),
      );

      expect(find.text('-1'), findsOneWidget);
      final after = tester.widget<Text>(find.text('+0.5'));
      expect(after.style?.color, AppColors.accent);
    });

    testWidgets('값이 같으면 하나만 보이고 강조하지 않는다', (tester) async {
      await tester.pumpWidget(
        _app(const ChangeRow(label: '컬러', before: '+2', after: '+2')),
      );

      expect(find.text('+2'), findsOneWidget);
      final value = tester.widget<Text>(find.text('+2'));
      expect(value.style?.color, isNot(AppColors.accent));
    });
  });

  testWidgets('SlotBadge 는 C 번호를 보인다', (tester) async {
    await tester.pumpWidget(_app(const SlotBadge(slot: 3, active: true)));

    expect(find.text('C3'), findsOneWidget);
  });
}
