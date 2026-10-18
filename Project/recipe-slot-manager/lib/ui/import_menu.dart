import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/camera/camera_session.dart';
import 'package:recipe_slot_manager/camera/slot_snapshot.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/import/file_pick.dart' as pick;
import 'package:recipe_slot_manager/import/fuji_makernote.dart';
import 'package:recipe_slot_manager/import/jpeg_exif.dart';
import 'package:recipe_slot_manager/import/recipe_import.dart';
import 'package:recipe_slot_manager/import/recipe_text_parser.dart';
import 'package:recipe_slot_manager/import/text_recognizer.dart' as ocr;
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/recipe/recipe_codec.dart';
import 'package:recipe_slot_manager/ui/recipe_editor_page.dart';

/// 가져오기가 쓰는 바깥 기능(파일 고르기, 글자 인식). 시험은 가짜로 바꾼다.
class ImportTools {
  const ImportTools({
    this.pickJpeg = pick.pickJpegHead,
    this.pickImage = pick.pickImage,
    this.recognizeText = ocr.recognizeText,
  });

  final Future<pick.PickedFile?> Function() pickJpeg;
  final Future<pick.PickedFile?> Function() pickImage;
  final Future<List<String>> Function(Uint8List image) recognizeText;
}

/// 레시피 목록 머리의 가져오기 메뉴. 고른 출처에서 값을 읽어 새 레시피 편집 화면을 연다.
class ImportMenu extends StatelessWidget {
  const ImportMenu({
    super.key,
    required this.library,
    required this.session,
    this.tools = const ImportTools(),
  });

  final LibraryStore library;
  final CameraSession session;
  final ImportTools tools;

  Future<void> _import(BuildContext context, ImportSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final imported = switch (source) {
        ImportSource.cameraSlot => await _fromCamera(context),
        ImportSource.exif => await _fromExif(),
        ImportSource.text => await _fromText(),
      };
      if (imported == null) return;
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => RecipeEditorPage(
            library: library,
            recipe: imported.recipe,
            isNew: true,
            note: imported.note,
          ),
        ),
      );
    } on ImportException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<ImportedRecipe?> _fromCamera(BuildContext context) async {
    if (!session.connected) {
      throw const ImportException('카메라를 먼저 연결할 것');
    }
    // 다른 작업이 슬롯을 바꾸는 중에 읽으면 그 작업이 엉뚱한 슬롯에 쓸 수 있다.
    if (session.busy) {
      throw const ImportException('카메라 작업이 끝난 뒤 다시 할 것');
    }
    var slots = const <SlotSnapshot>[];
    final failure = await session.run('7슬롯 읽기', () async {
      slots = await session.camera.readAllSlots();
    });
    if (failure != null) throw ImportException(failure);
    if (!context.mounted) return null;
    final slot = await showDialog<SlotSnapshot>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('가져올 슬롯'),
        children: [
          for (final slot in slots)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(slot),
              child: Text('C${slot.slot}  ${slot.name}'),
            ),
        ],
      ),
    );
    if (slot == null) return null;
    return importedRecipe(
      name: slot.name,
      values: decodeSlot(slot),
      source: ImportSource.cameraSlot,
    );
  }

  Future<ImportedRecipe?> _fromExif() async {
    final file = await tools.pickJpeg();
    if (file == null) return null;
    return importedRecipe(
      name: file.name,
      values: decodeFujiRecipe(readFujiTags(readMakerNote(file.bytes))),
      source: ImportSource.exif,
    );
  }

  Future<ImportedRecipe?> _fromText() async {
    final file = await tools.pickImage();
    if (file == null) return null;
    final values = parseRecipeText(await tools.recognizeText(file.bytes));
    if (values.isEmpty) {
      throw const ImportException('이미지에서 레시피 항목을 찾지 못했다');
    }
    return importedRecipe(
      name: file.name,
      values: values,
      source: ImportSource.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ImportSource>(
      onSelected: (source) => _import(context, source),
      itemBuilder: (_) => const [
        PopupMenuItem(value: ImportSource.cameraSlot, child: Text('카메라 슬롯')),
        PopupMenuItem(value: ImportSource.exif, child: Text('사진 (EXIF)')),
        PopupMenuItem(value: ImportSource.text, child: Text('이미지 글자 (OCR)')),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_outlined, size: 18),
              SizedBox(width: AppSpacing.xs),
              Text('가져오기'),
            ],
          ),
        ),
      ),
    );
  }
}
