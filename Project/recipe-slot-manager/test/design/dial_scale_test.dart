import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/design/app_theme.dart';
import 'package:recipe_slot_manager/design/dial_scale.dart';

void main() {
  group('snapToStep', () {
    test('간격의 배수로 반올림하고 부동소수 오차를 없앤다', () {
      expect(snapToStep(1.24, min: -2, max: 4, step: 0.5), 1.0);
      expect(snapToStep(1.26, min: -2, max: 4, step: 0.5), 1.5);
      expect(snapToStep(0.1 + 0.2, min: -1, max: 1, step: 0.1), 0.3);
      expect(snapToStep(5503, min: 2500, max: 10000, step: 10), 5500);
    });

    test('범위 밖은 끝 값으로 자른다', () {
      expect(snapToStep(9, min: -2, max: 4, step: 0.5), 4);
      expect(snapToStep(-9, min: -2, max: 4, step: 0.5), -2);
    });
  });

  group('DialScale', () {
    late double? changed;

    Future<void> pump(WidgetTester tester, {double value = 0}) async {
      changed = null;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: DialScale(
                label: '하이라이트',
                value: value,
                min: -2,
                max: 4,
                step: 0.5,
                onChanged: (v) => changed = v,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('현재 값과 이름을 보여 준다', (tester) async {
      await pump(tester, value: 1.5);

      expect(find.text('하이라이트'), findsOneWidget);
      expect(find.text('+1.5'), findsOneWidget);
    });

    testWidgets('→ 키는 한 간격 올리고 ← 키는 내린다', (tester) async {
      await pump(tester);
      await tester.tap(find.byType(DialScale));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(changed, 0.5);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(changed, -0.5);
    });

    testWidgets('최대값에서 → 키를 눌러도 범위를 넘지 않는다', (tester) async {
      await pump(tester, value: 4);
      await tester.tap(find.byType(DialScale));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

      expect(changed, isNull);
    });

    testWidgets('눈금을 왼쪽으로 끌면 값이 오른다', (tester) async {
      await pump(tester);

      await tester.drag(
        find.byType(DialScale),
        const Offset(-DialScale.tickSpacing * 2, 0),
      );

      expect(changed, 1.0);
    });

    testWidgets('슬라이더로 읽히고 값을 알린다', (tester) async {
      await pump(tester, value: -1);

      final semantics = tester.getSemantics(find.byType(DialScale));
      expect(semantics.value, '-1');
      expect(semantics.increasedValue, '-0.5');
      expect(semantics.decreasedValue, '-1.5');
    });
  });
}
