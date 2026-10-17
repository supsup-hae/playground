import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/design/app_theme.dart';
import 'package:recipe_slot_manager/design/dial_scale.dart';
import 'package:recipe_slot_manager/ui/design_gallery_page.dart';

void main() {
  testWidgets('갤러리는 렌더 오류 없이 컴포넌트를 보이고 조작에 반응한다', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: DesignGalleryPage()),
      ),
    );

    expect(find.byType(DialScale), findsNWidgets(2));
    expect(find.text('+1.5'), findsOneWidget);

    await tester.tap(find.text('강·대'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
