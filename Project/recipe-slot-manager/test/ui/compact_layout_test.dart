import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/library/loadout.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';
import 'package:recipe_slot_manager/ui/apply_loadout_page.dart';
import 'package:recipe_slot_manager/ui/design_gallery_page.dart';
import 'package:recipe_slot_manager/ui/sync_bar.dart';

import '../support/test_app.dart';

/// 갤럭시 S26 울트라 세로(기본 화면 크기), 화면 크기를 키운 경우, 가로.
const phoneSizes = {
  'S26 울트라 세로': Size(412, 915),
  '화면 크기 확대': Size(360, 800),
  'S26 울트라 가로': Size(915, 412),
};

void main() {
  late TestApp app;

  setUp(() => app = TestApp());
  tearDown(() => app.dispose());

  for (final MapEntry(key: name, value: size) in phoneSizes.entries) {
    group(name, () {
      testWidgets('아래 탭으로 네 화면을 넘침 없이 오간다', (tester) async {
        await tester.runAsync(app.session.connect);
        await app.pumpShell(
          tester,
          size: size,
          headerActions: const [SyncBar(sync: null, auth: null)],
        );

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('디자인'),
          ),
          findsNothing,
          reason: '디자인은 넓은 창 레일에만 있다',
        );
        for (final label in ['세트', '사용자 설정', 'RAW 미리보기', '사진', '레시피']) {
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
        }

        await tester.tap(find.text('사용자 설정').last);
        await tester.pumpAndSettle();
        await TestApp.tapAndWait(tester, find.text('C1–C7 불러오기'));
        expect(tester.takeException(), isNull, reason: '7슬롯 표');
      });

      testWidgets('디자인 화면을 끝까지 내려도 넘치지 않는다', (tester) async {
        await app.pumpPage(
          tester,
          const Scaffold(body: DesignGalleryPage()),
          size: size,
        );
        // 목록은 보이는 줄만 그리므로 끝까지 내려 모든 컴포넌트를 그린다.
        await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('로그는 한 줄로 접혀 있다가 누르면 펼쳐진다', (tester) async {
        await tester.runAsync(app.session.connect);
        await app.pumpShell(tester, size: size);
        final log = find.byKey(const ValueKey('log-panel'));
        final folded = tester.getSize(log).height;
        expect(folded, greaterThanOrEqualTo(kMinInteractiveDimension));

        await tester.tap(log);
        await tester.pumpAndSettle();

        expect(tester.getSize(log).height, greaterThan(folded));
        expect(tester.takeException(), isNull);
      });

      testWidgets('레시피 편집과 묶음 편집이 넘치지 않는다', (tester) async {
        await app.pumpShell(tester, size: size);
        await tester.tap(find.text('새 레시피'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '레시피 편집');

        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('세트').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('새 세트'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '묶음 편집');
      });

      testWidgets('비교·쓰기 화면이 넘치지 않는다', (tester) async {
        final loadout = (await tester.runAsync(() async {
          final night = await app.library.saveRecipe(
            Recipe(
              id: 'r-night',
              name: 'Night',
              values: const {'highlight': 1.5, 'filmSimulation': 0x11},
              updatedAt: DateTime.utc(2026),
            ),
          );
          await app.session.connect();
          return app.library.saveLoadout(
            Loadout(
              id: 'l1',
              name: '야간',
              slots: [null, night.id, null, null, null, null, null],
              updatedAt: DateTime.utc(2026),
            ),
          );
        }))!;
        await app.pumpPage(
          tester,
          ApplyLoadoutPage(
            session: app.session,
            library: app.library,
            loadout: loadout,
          ),
          size: size,
        );
        await TestApp.settle(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('C1–C7에 저장'), findsOneWidget);
      });
    });
  }

  testWidgets('글꼴을 크게 키운 좁은 화면에서도 카메라 막대가 넘치지 않는다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(app.session.connect);
    await app.pumpShell(
      tester,
      size: phoneSizes['화면 크기 확대']!,
      headerActions: const [SyncBar(sync: null, auth: null)],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('연결'), findsOneWidget);
  });

  testWidgets('창 크기가 배치 기준을 넘나들어도 화면 상태가 남는다', (tester) async {
    await tester.runAsync(app.session.connect);
    await app.pumpShell(tester, index: 2);
    await TestApp.tapAndWait(tester, find.text('C1–C7 불러오기'));
    expect(find.text('Recipe 7'), findsOneWidget);

    TestApp.useWindow(tester, phoneSizes['S26 울트라 세로']!);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Recipe 7'), findsOneWidget);
  });

  testWidgets('디자인 화면을 보다가 창이 좁아지면 첫 탭을, 넓어지면 디자인을 다시 보인다', (tester) async {
    await app.pumpShell(tester, index: 5);
    expect(find.byType(DesignGalleryPage), findsOneWidget);

    TestApp.useWindow(tester, phoneSizes['S26 울트라 세로']!);
    await tester.pumpAndSettle();
    expect(find.byType(DesignGalleryPage), findsNothing);
    expect(find.text('새 레시피'), findsOneWidget);

    TestApp.useWindow(tester);
    await tester.pumpAndSettle();
    expect(find.byType(DesignGalleryPage), findsOneWidget);
  });

  testWidgets('넓은 창에서는 왼쪽 레일을 그대로 쓴다', (tester) async {
    await app.pumpShell(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
