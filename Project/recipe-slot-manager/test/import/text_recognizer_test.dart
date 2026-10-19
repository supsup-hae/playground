import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/import/recipe_import.dart';
import 'package:recipe_slot_manager/import/text_recognizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Future<Object?> Function(MethodCall call) handler;

  setUp(
    () =>
        messenger.setMockMethodCallHandler(ocrChannel, (call) => handler(call)),
  );
  tearDown(() => messenger.setMockMethodCallHandler(ocrChannel, null));

  test('이미지 바이트를 보내고 읽은 줄을 돌려받는다', () async {
    MethodCall? sent;
    handler = (call) async {
      sent = call;
      return ['Film Simulation: Eterna', 'Shadow: -1'];
    };
    final image = Uint8List.fromList([1, 2, 3]);

    expect(await recognizeText(image), [
      'Film Simulation: Eterna',
      'Shadow: -1',
    ]);
    expect(sent?.method, 'recognize');
    expect(sent?.arguments, image);
  });

  test('플랫폼 오류는 ImportException 으로 바꾼다', () async {
    handler = (_) async =>
        throw PlatformException(code: 'image', message: '이미지를 열지 못했다');

    await expectLater(
      recognizeText(Uint8List(1)),
      throwsA(
        isA<ImportException>().having(
          (e) => e.message,
          'message',
          '텍스트를 인식하지 못했습니다: 이미지를 열지 못했다',
        ),
      ),
    );
  });
}
