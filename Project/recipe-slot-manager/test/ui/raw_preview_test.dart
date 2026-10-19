import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/camera/fuji_camera.dart';
import 'package:recipe_slot_manager/camera/raw_developer.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';
import 'package:recipe_slot_manager/ui/raw_preview_page.dart';

import '../support/test_app.dart';

void main() {
  late TestApp app;
  late RawDeveloper developer;

  setUp(() {
    app = TestApp();
    app.transport.rawBaseProfile = Uint8List(625)..[0] = 30;
    developer = RawDeveloper(
      FujiCamera(app.transport, slotSwitchDelay: Duration.zero),
      pollInterval: Duration.zero,
      pollTimeout: const Duration(seconds: 1),
    );
  });
  tearDown(() => app.dispose());

  Future<void> addRecipes(WidgetTester tester) => tester.runAsync(() async {
    for (final (id, name, highlight) in [
      ('r-a', 'Summer', 1.0),
      ('r-b', 'Night', -1.0),
    ]) {
      await app.library.saveRecipe(
        Recipe(
          id: id,
          name: name,
          values: {'highlight': highlight},
          updatedAt: DateTime.utc(2026),
        ),
      );
    }
  });

  Future<void> pumpPreview(WidgetTester tester, {Size? size}) => app.pumpPage(
    tester,
    Scaffold(
      body: RawPreviewPage(
        session: app.session,
        library: app.library,
        developer: developer,
        pickRaf: () async => (name: 'DSCF0042', bytes: Uint8List(1024)),
      ),
    ),
    size: size ?? TestApp.largeWindow,
  );

  Future<void> pick(WidgetTester tester, String key, String recipe) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(recipe).last);
    await tester.pumpAndSettle();
  }

  testWidgets('카메라가 연결되지 않았으면 RAF 를 보내지 않고 알린다', (tester) async {
    await pumpPreview(tester);

    await TestApp.tapAndWait(tester, find.text('RAF 선택'));

    expect(find.text('카메라를 먼저 연결하세요'), findsOneWidget);
    expect(app.transport.raf, isNull);
  });

  testWidgets('RAF 를 보내고 레시피 A·B 로 현상하면 결과 두 장이 나란히 보인다', (tester) async {
    await addRecipes(tester);
    await tester.runAsync(app.session.connect);
    await pumpPreview(tester);

    await TestApp.tapAndWait(tester, find.text('RAF 선택'));
    expect(find.textContaining('DSCF0042'), findsOneWidget);
    expect(app.transport.raf, hasLength(1024));

    await pick(tester, 'recipe-a', 'Summer');
    await pick(tester, 'recipe-b', 'Night');
    await TestApp.tapAndWait(tester, find.text('현상'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('result-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('result-b')), findsOneWidget);
    expect(app.transport.writtenProfiles, hasLength(2));
    final a = tester.getCenter(find.byKey(const ValueKey('result-a')));
    final b = tester.getCenter(find.byKey(const ValueKey('result-b')));
    expect(a.dy, b.dy, reason: '넓은 창에서는 나란히');
  });

  testWidgets('휴대폰 폭에서는 결과를 위아래로 쌓고 넘치지 않는다', (tester) async {
    await addRecipes(tester);
    await tester.runAsync(app.session.connect);
    await pumpPreview(tester, size: const Size(412, 915));

    await TestApp.tapAndWait(tester, find.text('RAF 선택'));
    await pick(tester, 'recipe-a', 'Summer');
    await pick(tester, 'recipe-b', 'Night');
    await TestApp.tapAndWait(tester, find.text('현상'));
    await tester.pumpAndSettle();

    final a = tester.getCenter(find.byKey(const ValueKey('result-a')));
    final b = tester.getCenter(find.byKey(const ValueKey('result-b')));
    expect(b.dy, greaterThan(a.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('RAF 가 없거나 레시피를 고르지 않으면 현상 버튼이 꺼져 있다', (tester) async {
    await addRecipes(tester);
    await tester.runAsync(app.session.connect);
    await pumpPreview(tester);

    final button = find.widgetWithText(FilledButton, '현상');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await TestApp.tapAndWait(tester, find.text('RAF 선택'));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await pick(tester, 'recipe-a', 'Summer');
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  testWidgets('현상이 실패하면 로그에 남고 결과 자리는 비어 있다', (tester) async {
    await addRecipes(tester);
    await tester.runAsync(app.session.connect);
    app.transport.developResult = (_) => Uint8List.fromList([1, 2, 3]);
    await pumpPreview(tester);

    await TestApp.tapAndWait(tester, find.text('RAF 선택'));
    await pick(tester, 'recipe-a', 'Summer');
    await TestApp.tapAndWait(tester, find.text('현상'));

    expect(
      app.session.log.entries.map((e) => e.$2),
      contains(startsWith('현상 A 실패')),
    );
    expect(find.byKey(const ValueKey('result-a')), findsNothing);
  });

  testWidgets('결과는 폭 2048 px 로 줄여 그리고, 화면 낭독기에 확대할 수 있다고 알린다', (tester) async {
    final semantics = tester.ensureSemantics();
    await addRecipes(tester);
    await tester.runAsync(app.session.connect);
    await pumpPreview(tester);
    await TestApp.tapAndWait(tester, find.text('RAF 선택'));
    await pick(tester, 'recipe-a', 'Summer');
    await TestApp.tapAndWait(tester, find.text('현상'));
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('result-a')),
        matching: find.byType(Image),
      ),
    );
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).width, 2048);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('result-a'))).label,
      startsWith('결과 A 크게 보기'),
    );
    semantics.dispose();
  });

  testWidgets('보관함에 레시피가 없으면 만들거나 가져오라고 알린다', (tester) async {
    await pumpPreview(tester);

    expect(find.textContaining('보관함에 레시피가 없습니다'), findsOneWidget);
  });
}
