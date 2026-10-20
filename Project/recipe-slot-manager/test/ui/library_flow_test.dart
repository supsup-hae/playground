import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/library/loadout.dart';
import 'package:recipe_slot_manager/photo/locator.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';
import 'package:recipe_slot_manager/ui/apply_loadout_page.dart';

import '../support/test_app.dart';

void main() {
  late TestApp app;

  setUp(() => app = TestApp());
  tearDown(() => app.dispose());

  testWidgets('셸은 모든 목적지 화면을 오류 없이 오간다', (tester) async {
    await app.pumpShell(tester);

    for (final label in ['세트', '사용자 설정', 'RAW 미리보기', '사진', '디자인', '레시피']) {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
    expect(find.text('카메라 연결 안 됨'), findsOneWidget);
  });

  testWidgets('새 레시피에서 흑백 시뮬레이션을 고르면 컬러 대신 모노 필드가 보이고, 저장된다', (tester) async {
    await app.pumpShell(tester);
    await tester.tap(find.text('새 레시피'));
    await tester.pumpAndSettle();

    expect(find.text('색농도'), findsOneWidget);
    expect(find.text('모노크롬 색상 WC'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('set-filmSimulation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acros'));
    await tester.pumpAndSettle();

    expect(find.text('색농도'), findsNothing);
    expect(find.text('모노크롬 색상 WC'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('recipe-name')), 'B&W');
    await TestApp.tapAndWait(tester, find.text('저장'));

    final saved = app.library.recipes.single;
    expect(saved.name, 'B&W');
    expect(saved.values, {'filmSimulation': 0x0C});
    await tester.pumpAndSettle();
    expect(find.text('B&W'), findsOneWidget, reason: '목록으로 돌아온다');
  });

  testWidgets('새 세트에서 C2 에 레시피를 고르고 저장한다', (tester) async {
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
    await tester.tap(find.text('새 세트'));
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
          placeLogger: app.placeLogger,
        ),
      );
      await TestApp.settle(tester);
    }

    testWidgets('슬롯별로 바뀌는 값을 사람이 읽는 값으로 보인다', (tester) async {
      await prepare(tester);

      expect(find.text('Night'), findsWidgets);
      expect(find.text('하이라이트'), findsOneWidget);
      expect(find.text('+1.5'), findsOneWidget);
      expect(find.text('변경 없음'), findsNWidgets(6));
    });

    testWidgets('쓰기가 실패하면 비교를 비우고 다시 읽게 하며 로그에 남긴다', (tester) async {
      await prepare(tester);
      app.transport.rejectSet[0xD18C] = 0x201D;

      await TestApp.tapAndWait(tester, find.text('C1–C7에 저장'));

      expect(find.text('다시 불러오기'), findsOneWidget);
      expect(
        app.session.log.entries.map((e) => e.$2),
        contains(startsWith('C1–C7에 저장 실패')),
      );
    });

    testWidgets('7슬롯 쓰기는 백업을 남기고, 레시피가 있는 슬롯만 쓰고, 걸린 시간을 보인다', (tester) async {
      await prepare(tester);
      app.transport.sent.clear();

      await TestApp.tapAndWait(tester, find.text('C1–C7에 저장'));

      expect(app.transport.slots[2]![0xD19D], u16(15));
      expect(app.transport.slots[1]![0xD19D], u16(1));
      expect(app.transport.slots[3]![0xD19D], u16(3));
      final backups = (await tester.runAsync(app.backups.list))!;
      expect(backups, hasLength(1));
      expect(find.textContaining('초'), findsOneWidget);
    });

    testWidgets('저장이 끝나면 위치 권한을 먼저 묻고, 위치와 세트를 기록한다', (tester) async {
      app.locator.fix = (
        point: (latitude: 35.6587, longitude: 139.7005),
        accuracy: 8,
      );
      await prepare(tester);

      await TestApp.tapAndWait(tester, find.text('C1–C7에 저장'));
      await TestApp.settle(tester);

      expect(app.locator.accessRequests, 1);
      final saved = app.placeLogStore.logs.single;
      expect(saved.loadoutName, '야간');
      expect(saved.slots, [null, 'Night', null, null, null, null, null]);
      expect(saved.location, (latitude: 35.6587, longitude: 139.7005));
      expect(saved.model, app.session.model);
    });

    testWidgets('위치 권한을 거부해도 저장하고 위치 없이 기록한다', (tester) async {
      app.locator
        ..granted = false
        ..failure = const LocateException('denied', '위치 권한이 없습니다');
      await prepare(tester);

      await TestApp.tapAndWait(tester, find.text('C1–C7에 저장'));
      await TestApp.settle(tester);

      expect(app.transport.slots[2]![0xD19D], u16(15));
      expect(app.placeLogStore.logs.single.missingReason, '위치 권한이 없습니다');
    });

    testWidgets('저장이 실패하면 기록하지 않는다', (tester) async {
      await prepare(tester);
      app.transport.rejectSet[0xD18C] = 0x201D;

      await TestApp.tapAndWait(tester, find.text('C1–C7에 저장'));
      await TestApp.settle(tester);

      expect(app.placeLogStore.logs, isEmpty);
    });
  });
}
