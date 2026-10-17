import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/library/loadout.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';
import 'package:recipe_slot_manager/ui/apply_loadout_page.dart';

import '../support/test_app.dart';

void main() {
  late TestApp app;

  setUp(() => app = TestApp());
  tearDown(() => app.dispose());

  testWidgets('셸은 레시피·묶음·원시 값·디자인 화면을 오류 없이 오간다', (tester) async {
    await app.pumpShell(tester);

    for (final label in ['묶음', '원시 값', '디자인', '레시피']) {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
    expect(find.text('카메라 없음'), findsOneWidget);
  });

  testWidgets('새 레시피에서 흑백 시뮬레이션을 고르면 컬러 대신 모노 필드가 보이고, 저장된다', (tester) async {
    await app.pumpShell(tester);
    await tester.tap(find.text('새 레시피'));
    await tester.pumpAndSettle();

    expect(find.text('컬러'), findsOneWidget);
    expect(find.text('모노 웜·쿨'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('set-filmSimulation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acros'));
    await tester.pumpAndSettle();

    expect(find.text('컬러'), findsNothing);
    expect(find.text('모노 웜·쿨'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('recipe-name')), 'B&W');
    await TestApp.tapAndWait(tester, find.text('저장'));

    final saved = app.library.recipes.single;
    expect(saved.name, 'B&W');
    expect(saved.values, {'filmSimulation': 0x0C});
    await tester.pumpAndSettle();
    expect(find.text('B&W'), findsOneWidget, reason: '목록으로 돌아온다');
  });

  testWidgets('새 묶음에서 C2 에 레시피를 고르고 저장한다', (tester) async {
    final kodak = (await tester.runAsync(
      () => app.library.saveRecipe(
        Recipe(
          id: newRecipeId(),
          name: 'Kodak',
          values: const {'filmSimulation': 0x11},
          updatedAt: DateTime.utc(2026),
        ),
      ),
    ))!;
    await app.pumpShell(tester, index: 1);
    await tester.tap(find.text('새 묶음'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('slot-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kodak').last);
    await tester.pumpAndSettle();
    await TestApp.tapAndWait(tester, find.text('저장'));

    final saved = app.library.loadouts.single;
    expect(saved.slots, [null, kodak.id, null, null, null, null, null]);
  });

  group('ApplyLoadoutPage', () {
    late Loadout loadout;

    Future<void> prepare(WidgetTester tester) async {
      await tester.runAsync(() async {
        final night = await app.library.saveRecipe(
          Recipe(
            id: 'r-night',
            name: 'Night',
            values: const {'highlight': 1.5},
            updatedAt: DateTime.utc(2026),
          ),
        );
        loadout = await app.library.saveLoadout(
          Loadout(
            id: 'l1',
            name: '야간',
            slots: [null, night.id, null, null, null, null, null],
            updatedAt: DateTime.utc(2026),
          ),
        );
        await app.session.connect();
      });
      await app.pumpPage(
        tester,
        ApplyLoadoutPage(
          session: app.session,
          library: app.library,
          loadout: loadout,
        ),
      );
      await TestApp.settle(tester);
    }

    testWidgets('슬롯별로 바뀌는 값을 사람이 읽는 값으로 보인다', (tester) async {
      await prepare(tester);

      expect(find.text('Night'), findsWidgets);
      expect(find.text('하이라이트'), findsOneWidget);
      expect(find.text('+1.5'), findsOneWidget);
      expect(find.text('그대로'), findsNWidgets(6));
    });

    testWidgets('7슬롯 쓰기는 백업을 남기고, 레시피가 있는 슬롯만 쓰고, 걸린 시간을 보인다', (tester) async {
      await prepare(tester);
      app.transport.sent.clear();

      await TestApp.tapAndWait(tester, find.text('7슬롯 쓰기'));

      expect(app.transport.slots[2]![0xD19D], u16(15));
      expect(app.transport.slots[1]![0xD19D], u16(1));
      expect(app.transport.slots[3]![0xD19D], u16(3));
      final backups = (await tester.runAsync(app.backups.list))!;
      expect(backups, hasLength(1));
      expect(find.textContaining('초'), findsOneWidget);
    });
  });
}
