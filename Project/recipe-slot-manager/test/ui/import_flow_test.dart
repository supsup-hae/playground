import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/import/file_pick.dart';
import 'package:recipe_slot_manager/ptp/ptp_transport.dart';
import 'package:recipe_slot_manager/ui/import_menu.dart';
import 'package:recipe_slot_manager/ui/recipe_list_page.dart';

import '../support/exif_builder.dart';
import '../support/test_app.dart';

void main() {
  late TestApp app;
  PickedFile? picked;
  List<String> recognized = const [];

  setUp(() {
    app = TestApp();
    picked = null;
    recognized = const [];
  });
  tearDown(() => app.dispose());

  Future<void> pumpList(WidgetTester tester) => app.pumpPage(
    tester,
    Scaffold(
      body: RecipeListPage(
        library: app.library,
        session: app.session,
        importTools: ImportTools(
          pickJpeg: () async => picked,
          pickImage: () async => picked,
          recognizeText: (_) async => recognized,
        ),
      ),
    ),
  );

  Future<void> choose(WidgetTester tester, String source) async {
    await tester.tap(find.text('가져오기'));
    await tester.pumpAndSettle();
    await TestApp.tapAndWait(tester, find.text(source).last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await TestApp.tapAndWait(tester, find.text('저장'));
    await tester.pumpAndSettle();
  }

  testWidgets('카메라가 연결되지 않았으면 연결부터 하라고 알린다', (tester) async {
    await pumpList(tester);

    await choose(tester, '카메라 슬롯');

    expect(find.text('카메라를 먼저 연결할 것'), findsOneWidget);
  });

  testWidgets('다른 카메라 작업 중이면 끝난 뒤 하라고 알리고 카메라에 명령을 보내지 않는다', (tester) async {
    await tester.runAsync(app.session.connect);
    final running = Completer<void>();
    unawaited(app.session.run('쓰기', () => running.future));
    app.transport.sent.clear();
    await pumpList(tester);

    await choose(tester, '카메라 슬롯');

    expect(find.text('카메라 작업이 끝난 뒤 다시 할 것'), findsOneWidget);
    expect(app.transport.sent, isEmpty);
    running.complete();
    await TestApp.settle(tester);
  });

  testWidgets('슬롯을 읽지 못하면 이유를 알린다', (tester) async {
    await tester.runAsync(app.session.connect);
    app.transport.failure = const PtpTransportException('USB 응답 시간 초과');
    await pumpList(tester);

    await choose(tester, '카메라 슬롯');

    expect(find.text('USB 응답 시간 초과'), findsOneWidget);
  });

  testWidgets('슬롯 고르기를 닫으면 편집 화면을 열지 않는다', (tester) async {
    await tester.runAsync(app.session.connect);
    await pumpList(tester);

    await choose(tester, '카메라 슬롯');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('가져올 슬롯'), findsNothing);
    expect(find.text('저장'), findsNothing);
  });

  testWidgets('가져오기 버튼은 손가락으로 누를 수 있는 최소 크기다', (tester) async {
    await pumpList(tester);

    final size = tester.getSize(find.byType(ImportMenu));

    expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
  });

  testWidgets('카메라 슬롯을 고르면 그 슬롯 이름과 값으로 편집 화면이 열린다', (tester) async {
    await tester.runAsync(app.session.connect);
    await pumpList(tester);

    await choose(tester, '카메라 슬롯');
    await TestApp.tapAndWait(tester, find.text('C3  Recipe 3'));
    await tester.pumpAndSettle();

    expect(find.textContaining('카메라 슬롯에서'), findsOneWidget);
    await save(tester);
    expect(app.library.recipes.single.name, 'Recipe 3');
  });

  testWidgets('JPEG 을 고르면 EXIF 값으로 편집 화면이 열리고 저장된다', (tester) async {
    picked = (
      name: 'DSCF0001',
      bytes: jpegWithExif(
        makerNote: fujiMakerNote({
          0x1401: (tiffShort, [0x600]),
          0x1041: (tiffSLong, [-16]),
          0x1047: (tiffSLong, [64]),
        }),
      ),
    );
    await pumpList(tester);

    await choose(tester, '사진 (EXIF)');

    expect(find.text('EXIF에서 3개 항목을 읽었다. 빈칸은 카메라 값을 유지한다'), findsOneWidget);
    await save(tester);
    final saved = app.library.recipes.single;
    expect(saved.name, 'DSCF0001');
    expect(saved.values, {'filmSimulation': 0x0B, 'highlight': 1, 'grain': 3});
  });

  testWidgets('JPEG 이 아니면 이유를 알리고 편집 화면을 열지 않는다', (tester) async {
    picked = (
      name: 'shot',
      bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
    );
    await pumpList(tester);

    await choose(tester, '사진 (EXIF)');

    expect(find.text('JPEG 파일이 아니다'), findsOneWidget);
    expect(find.text('저장'), findsNothing);
  });

  testWidgets('이미지 글자에서 읽은 항목으로 편집 화면이 열린다', (tester) async {
    picked = (name: 'insta', bytes: Uint8List(4));
    recognized = ['Film Simulation: Eterna', 'Shadow: -1'];
    await pumpList(tester);

    await choose(tester, '이미지 글자 (OCR)');

    expect(find.textContaining('이미지 글자에서 2개 항목'), findsOneWidget);
    await save(tester);
    expect(app.library.recipes.single.values, {
      'filmSimulation': 0x10,
      'shadow': -1,
    });
  });

  testWidgets('이미지에서 레시피 항목을 찾지 못하면 알린다', (tester) async {
    picked = (name: 'cat', bytes: Uint8List(4));
    recognized = ['고양이 사진'];
    await pumpList(tester);

    await choose(tester, '이미지 글자 (OCR)');

    expect(find.text('이미지에서 레시피 항목을 찾지 못했다'), findsOneWidget);
  });

  testWidgets('파일을 고르지 않으면 아무 일도 없다', (tester) async {
    await pumpList(tester);

    await choose(tester, '사진 (EXIF)');

    expect(find.text('저장'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}
