import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/photo/album_reader.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/ui/photo_source_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, Object?> replies;

  setUp(() {
    replies = {
      'requestAccess': {'images': true, 'location': true},
      'albums': [
        {'id': '-17', 'name': 'FUJIFILM XApp', 'count': 1204},
        {'id': '-3', 'name': 'Camera', 'count': 88},
      ],
    };
    messenger.setMockMethodCallHandler(
      photoChannel,
      (call) async => replies[call.method],
    );
  });
  tearDown(() => messenger.setMockMethodCallHandler(photoChannel, null));

  /// 고른 출처, 또는 던진 오류.
  Future<Future<Object?>> open(WidgetTester tester) async {
    late Future<Object?> picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => picked = pickAlbumSource(
              context,
              AlbumReader(),
            ).then<Object?>((s) => s, onError: (Object e) => e),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('권한을 받은 뒤 앨범 목록에서 고른 앨범을 출처로 돌려준다', (tester) async {
    final picked = await open(tester);

    expect(find.text('FUJIFILM XApp (1204장)'), findsOneWidget);
    await tester.tap(find.text('FUJIFILM XApp (1204장)'));
    await tester.pumpAndSettle();

    final source = await picked as PhotoSource?;
    expect(source?.kind, PhotoSourceKind.album);
    expect(source?.name, 'FUJIFILM XApp');
    expect(source?.location, '-17');
  });

  testWidgets('목록을 닫으면 null', (tester) async {
    final picked = await open(tester);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(await picked, isNull);
  });

  testWidgets('사진 권한을 거부하면 PhotoSourceException', (tester) async {
    replies['requestAccess'] = {'images': false, 'location': false};

    final picked = await open(tester);

    expect(await picked, isA<PhotoSourceException>());
  });
}
