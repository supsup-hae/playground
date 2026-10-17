import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/camera/slot_backup_store.dart';

import '../support/fake_ptp_transport.dart';
import '../support/test_app.dart';

const highlight = 0xD19D;

void main() {
  late TestApp app;
  late Directory root;
  late FakePtpTransport transport;
  late SlotBackupStore store;

  setUp(() {
    app = TestApp();
    root = app.backups.directory..createSync(recursive: true);
    transport = app.transport;
    store = app.backups;
  });

  tearDown(() => app.dispose());

  Future<void> pumpPage(WidgetTester tester) => app.pumpShell(tester, index: 2);

  Future<void> tapAndWait(WidgetTester tester, Finder finder) =>
      TestApp.tapAndWait(tester, finder);

  testWidgets('연결 후 7슬롯을 읽으면 슬롯 이름이 표에 보인다', (tester) async {
    await pumpPage(tester);

    await tapAndWait(tester, find.text('연결'));
    await tapAndWait(tester, find.text('7슬롯 읽기'));

    expect(find.text('X-T5'), findsOneWidget);
    expect(find.text('Recipe 5'), findsOneWidget);
  });

  testWidgets('값을 바꿔 쓰면 백업을 먼저 남기고 카메라에 쓴다', (tester) async {
    await pumpPage(tester);
    await tapAndWait(tester, find.text('연결'));
    await tapAndWait(tester, find.text('7슬롯 읽기'));

    await tester.tap(find.byKey(const ValueKey('cell-7-D19D')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '15');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    await tapAndWait(tester, find.text('C7 쓰기'));

    expect(transport.slots[7]![highlight], u16(15));
    final backups = await tester.runAsync(store.list);
    expect(backups, hasLength(1));
  });

  Future<void> connectAndRead(WidgetTester tester) async {
    await pumpPage(tester);
    await tapAndWait(tester, find.text('연결'));
    await tapAndWait(tester, find.text('7슬롯 읽기'));
  }

  Future<void> editCell(
    WidgetTester tester,
    int slot,
    String code,
    String text,
  ) async {
    await tester.tap(find.byKey(ValueKey('cell-$slot-$code')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
  }

  testWidgets('쓰기 전 백업과 비교 기준은 카메라에서 새로 읽은 값이다', (tester) async {
    const shadow = 0xD19E;
    await connectAndRead(tester);
    // 화면에서 읽은 뒤 카메라 본체에서 C7 섀도가 바뀐 상황.
    transport.slots[7]![shadow] = u16(77);

    await editCell(tester, 7, 'D19D', '15');
    await tapAndWait(tester, find.text('C7 쓰기'));

    final files = (await tester.runAsync(store.list))!;
    final backup = (await tester.runAsync(() => store.load(files.single)))!;
    expect(backup.slots[6].props[shadow], u16(77));
    expect(transport.slots[7]![shadow], u16(77));
    expect(transport.slots[7]![highlight], u16(15));
  });

  testWidgets('범위를 벗어난 값은 오류를 보이고 수정으로 남기지 않는다', (tester) async {
    await connectAndRead(tester);

    await editCell(tester, 7, 'D19D', '70000');

    expect(find.textContaining('범위'), findsOneWidget);
    expect(find.text('C7 쓰기'), findsNothing);
  });

  testWidgets('한 슬롯을 써도 다른 슬롯의 수정은 남는다', (tester) async {
    await connectAndRead(tester);
    await editCell(tester, 6, 'D19D', '10');
    await editCell(tester, 7, 'D19D', '15');

    await tapAndWait(tester, find.text('C7 쓰기'));

    expect(find.text('C6 쓰기'), findsOneWidget);
    expect(find.text('C7 쓰기'), findsNothing);
  });

  Future<void> restoreFrom(WidgetTester tester, String content) async {
    await tester.runAsync(
      () =>
          File('${root.path}/slots-20990101-000000-000.json')
              .writeAsString(content),
    );
    await tapAndWait(tester, find.text('백업에서 복원'));
    await tapAndWait(tester, find.text('slots-20990101-000000-000.json'));
  }

  testWidgets('형식이 잘못된 백업은 쓰지 않고 로그에 남긴다', (tester) async {
    await connectAndRead(tester);
    transport.sent.clear();

    await restoreFrom(tester, '{"model": "X-T5", "slots": "broken"}');

    expect(find.textContaining('복원 실패'), findsOneWidget);
    expect(transport.propWrites, isEmpty);
  });

  testWidgets('다른 모델의 백업은 쓰지 않고 로그에 남긴다', (tester) async {
    await connectAndRead(tester);
    transport.sent.clear();

    await restoreFrom(
      tester,
      '{"model": "X-H2", "createdAt": "2026-10-16T00:00:00.000Z", '
      '"slots": [{"slot": 1, "name": "C1", "props": {"D19D": "0f00"}}]}',
    );

    expect(find.textContaining('X-H2'), findsOneWidget);
    expect(transport.propWrites, isEmpty);
  });
}
