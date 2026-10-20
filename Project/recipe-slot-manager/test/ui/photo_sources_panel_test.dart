import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/ui/photo_sources_panel.dart';

import '../support/fake_photo_reader.dart';
import '../support/test_app.dart';

void main() {
  late TestApp app;

  const folder = PhotoSource(
    id: 's1',
    kind: PhotoSourceKind.folder,
    name: 'X-T5',
    location: '/photos/X-T5',
  );

  setUp(() => app = TestApp());
  tearDown(() => app.dispose());

  Future<void> pumpPhotos(
    WidgetTester tester, {
    PhotoSource? picked = folder,
    Size size = TestApp.largeWindow,
    Future<void> Function()? allowLocation,
  }) => app.pumpPage(
    tester,
    Scaffold(
      body: PhotoSourcesPanel(
        setup: app.photos(
          addSource: (_) async => picked,
          allowLocation: allowLocation,
        ),
      ),
    ),
    size: size,
  );

  testWidgets('출처가 없으면 추가하라고 알리고 읽기 버튼이 꺼져 있다', (tester) async {
    await pumpPhotos(tester);

    expect(find.textContaining('사진 폴더를 추가하세요'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '새 사진 읽기'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('출처를 추가하고 새 사진을 읽으면 요약과 로그가 보인다', (tester) async {
    app.photoReader
      ..put('a.jpg', bytes: fujiJpeg(filmMode: 0x700))
      ..put('b.jpg', bytes: fujiJpeg(filmMode: 0x700, imageCount: 2))
      ..put('c.jpg', bytes: fujiJpeg(filmMode: 0x800, imageCount: 3))
      ..put('d.jpg', bytes: Uint8List.fromList([1, 2]));
    await pumpPhotos(tester);

    await TestApp.tapAndWait(tester, find.text('추가'));
    expect(find.text('X-T5'), findsOneWidget);

    await TestApp.tapAndWait(tester, find.text('새 사진 읽기'));

    expect(find.text('전체 4장 · 위치 있음 0장 · 읽지 못함 1장'), findsOneWidget);
    expect(find.text('Eterna 2'), findsOneWidget);
    expect(find.text('Classic Neg. 1'), findsOneWidget);
    expect(find.textContaining('4장'), findsWidgets);
    expect(
      app.session.log.entries.map((e) => e.$2),
      contains(startsWith('사진 색인: 새로 4')),
    );
  });

  testWidgets('같은 출처를 두 번 추가하지 않는다', (tester) async {
    await pumpPhotos(tester);
    await TestApp.tapAndWait(tester, find.text('추가'));

    await TestApp.tapAndWait(tester, find.text('추가'));

    expect(app.photoStore.sources, hasLength(1));
    expect(find.text('이미 추가한 출처입니다'), findsOneWidget);
  });

  testWidgets('이미 추가한 폴더의 상위·하위 폴더는 추가하지 않는다', (tester) async {
    for (final (existing, picked) in [
      ('Pictures/FUJIFILM XApp/', 'Pictures/FUJIFILM XApp/2026/'),
      ('Pictures/FUJIFILM XApp/2026/', 'Pictures/'),
      ('Pictures/', ''),
    ]) {
      await tester.runAsync(() async {
        for (final s in app.photoStore.sources) {
          await app.photoStore.removeSource(s.id);
        }
        await app.photoStore.saveSource(
          PhotoSource(
            id: 'old',
            kind: PhotoSourceKind.mediaFolder,
            name: 'old',
            location: existing,
          ),
        );
      });
      await pumpPhotos(
        tester,
        picked: PhotoSource(
          id: 'new',
          kind: PhotoSourceKind.mediaFolder,
          name: 'new',
          location: picked,
        ),
      );

      await TestApp.tapAndWait(tester, find.text('추가'));

      expect(app.photoStore.sources.map((s) => s.id), ['old'], reason: picked);
      expect(find.text('이미 추가한 폴더와 겹칩니다'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(PhotoSourcesPanel)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('이름이 겹칠 뿐인 옆 폴더는 추가한다', (tester) async {
    await tester.runAsync(
      () => app.photoStore.saveSource(
        const PhotoSource(
          id: 'old',
          kind: PhotoSourceKind.folder,
          name: 'X-T5',
          location: '/photos/X-T5',
        ),
      ),
    );
    await pumpPhotos(
      tester,
      picked: const PhotoSource(
        id: 'new',
        kind: PhotoSourceKind.folder,
        name: 'X-T5 old',
        location: '/photos/X-T5 old',
      ),
    );

    await TestApp.tapAndWait(tester, find.text('추가'));

    expect(app.photoStore.sources, hasLength(2));
  });

  testWidgets('출처를 빼면 확인한 뒤 그 출처의 색인을 지운다', (tester) async {
    app.photoReader.put('a.jpg');
    await pumpPhotos(tester);
    await TestApp.tapAndWait(tester, find.text('추가'));
    await TestApp.tapAndWait(tester, find.text('새 사진 읽기'));

    await TestApp.tapAndWait(tester, find.byTooltip('목록에서 빼기'));
    await TestApp.tapAndWait(tester, find.text('빼기'));

    expect(app.photoStore.sources, isEmpty);
    expect(app.photoStore.photos, isEmpty);
  });

  testWidgets('출처를 읽지 못하면 이유를 알리고 색인을 그대로 둔다', (tester) async {
    app.photoReader.listError = const PhotoSourceException(
      '폴더를 찾을 수 없습니다: X-T5',
    );
    await pumpPhotos(tester);
    await TestApp.tapAndWait(tester, find.text('추가'));

    await TestApp.tapAndWait(tester, find.text('새 사진 읽기'));

    expect(find.text('폴더를 찾을 수 없습니다: X-T5'), findsOneWidget);
    expect(app.photoStore.photos, isEmpty);
  });

  testWidgets('위치가 가려진 사진이 있으면 허용 안내를 보이고 누르면 요청한다', (tester) async {
    var asked = 0;
    app.photoReader.put('a.jpg', redacted: true);
    await pumpPhotos(tester, allowLocation: () async => asked++);
    await TestApp.tapAndWait(tester, find.text('추가'));
    await TestApp.tapAndWait(tester, find.text('새 사진 읽기'));

    expect(find.textContaining('사진 위치 접근이 허용되지 않아'), findsOneWidget);
    await TestApp.tapAndWait(tester, find.text('허용'));

    expect(asked, 1);
  });

  testWidgets('휴대폰 폭에서도 넘치지 않는다', (tester) async {
    app.photoReader.put('a.jpg');
    await pumpPhotos(tester, size: const Size(360, 800));
    await TestApp.tapAndWait(tester, find.text('추가'));
    await TestApp.tapAndWait(tester, find.text('새 사진 읽기'));

    expect(tester.takeException(), isNull);
  });
}
