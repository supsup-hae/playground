import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/photo/auto_index.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';

import '../support/test_app.dart';

void main() {
  late TestApp app;

  setUp(() => app = TestApp());
  tearDown(() => app.dispose());

  testWidgets('시작하면 바로 읽고, 앱이 다시 앞으로 오면 새 사진을 읽는다', (tester) async {
    final setup = app.photos();
    await tester.runAsync(
      () => app.photoStore.saveSource(
        const PhotoSource(
          id: 's1',
          kind: PhotoSourceKind.folder,
          name: 'X-T5',
          location: '/photos',
        ),
      ),
    );
    app.photoReader.put('a.jpg');

    final listener = startAutoIndex(setup.indexer);
    addTearDown(listener.dispose);
    await TestApp.settle(tester);
    expect(app.photoStore.photos, hasLength(1));

    app.photoReader.put('b.jpg');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await TestApp.settle(tester);

    expect(app.photoStore.photos, hasLength(2));
    expect(app.photoReader.reads, ['a.jpg', 'b.jpg']);
  });
}
