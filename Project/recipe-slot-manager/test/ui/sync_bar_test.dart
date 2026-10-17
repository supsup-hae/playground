import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/ui/sync_bar.dart';

void main() {
  testWidgets('Supabase 설정이 없으면 동기화 버튼은 비활성으로 보인다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SyncBar(sync: null, auth: null))),
    );

    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(find.text('동기화 설정 없음'), findsOneWidget);
    expect(button.onPressed, isNull);
  });
}
