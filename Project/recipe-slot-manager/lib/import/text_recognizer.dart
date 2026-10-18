import 'package:flutter/services.dart';
import 'package:recipe_slot_manager/import/recipe_import.dart';

/// 이미지 글자 인식 채널. macOS 는 `macos/Runner/OcrChannel.swift`(Vision),
/// Android 는 `android/.../OcrChannel.kt`(ML Kit 한국어)가 받는다.
const ocrChannel = MethodChannel('recipe_slot_manager/ocr');

/// [image] 의 글자를 줄 단위로 읽는다.
Future<List<String>> recognizeText(Uint8List image) async {
  try {
    return await ocrChannel.invokeListMethod<String>('recognize', image) ??
        const [];
  } on PlatformException catch (e) {
    throw ImportException('글자를 읽지 못했다: ${e.message ?? e.code}');
  } on MissingPluginException {
    throw const ImportException('이 플랫폼에는 글자 인식 기능이 없다');
  }
}
