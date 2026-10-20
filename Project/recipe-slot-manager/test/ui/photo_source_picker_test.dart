import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/photo/media_folder_reader.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/ui/photo_source_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, Object?> replies;
  late List<String> calls;

  setUp(() {
    calls = [];
    replies = {
      'requestAccess': {'images': true, 'location': true},
      'pickFolder': {
        'path': 'Pictures/FUJIFILM XApp/',
        'name': 'FUJIFILM XApp',
      },
    };
    messenger.setMockMethodCallHandler(photoChannel, (call) async {
      calls.add(call.method);
      return replies[call.method];
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(photoChannel, null));

  test('권한을 받은 뒤 폴더 선택 창에서 고른 폴더를 출처로 돌려준다', () async {
    final source = await pickMediaFolderSource(MediaFolderReader());

    expect(calls, ['requestAccess', 'pickFolder']);
    expect(source?.kind, PhotoSourceKind.mediaFolder);
    expect(source?.name, 'FUJIFILM XApp');
    expect(source?.location, 'Pictures/FUJIFILM XApp/');
  });

  test('폴더 선택을 닫으면 null', () async {
    replies['pickFolder'] = <String, Object?>{};

    expect(await pickMediaFolderSource(MediaFolderReader()), isNull);
  });

  test('사진 권한을 거부하면 폴더 선택 창을 열지 않고 PhotoSourceException', () async {
    replies['requestAccess'] = {'images': false, 'location': false};

    await expectLater(
      pickMediaFolderSource(MediaFolderReader()),
      throwsA(isA<PhotoSourceException>()),
    );
    expect(calls, ['requestAccess']);
  });
}
