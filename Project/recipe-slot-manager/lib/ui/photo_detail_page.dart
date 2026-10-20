import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/import/recipe_import.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/photo/photo_info.dart';
import 'package:recipe_slot_manager/photo/photo_query.dart';
import 'package:recipe_slot_manager/recipe/recipe_fields.dart';
import 'package:recipe_slot_manager/ui/formats.dart';
import 'package:recipe_slot_manager/ui/photos_setup.dart';
import 'package:recipe_slot_manager/ui/recipe_editor_page.dart';

/// 사진을 원본 전체로 읽을 때의 상한.
const _wholeFile = 64 * 1024 * 1024;

/// 사진 한 장: 사진, 촬영 시각, 장소, 기종, 레시피 값, 레시피로 가져오기.
class PhotoDetailPage extends StatefulWidget {
  const PhotoDetailPage({
    super.key,
    required this.entry,
    required this.setup,
    required this.library,
  });

  final PhotoEntry entry;
  final PhotosSetup setup;
  final LibraryStore library;

  @override
  State<PhotoDetailPage> createState() => _PhotoDetailPageState();
}

class _PhotoDetailPageState extends State<PhotoDetailPage> {
  /// 사진 원본은 화면을 만들 때 한 번만 읽는다.
  late final _image = _loadImage();

  PhotoEntry get entry => widget.entry;
  PhotosSetup get setup => widget.setup;
  LibraryStore get library => widget.library;

  Future<Uint8List?> _loadImage() async {
    final photo = entry.photo;
    final source = setup.store.sourceById(photo.sourceId);
    final reader = source == null ? null : setup.indexer.readers[source.kind];
    if (source == null || reader == null) return null;
    final head = await reader.readHead(source, photo.file, length: _wholeFile);
    return head.bytes;
  }

  void _importRecipe(BuildContext context, PhotoInfo info) {
    final imported = importedRecipe(
      name: p.basenameWithoutExtension(entry.photo.file.name),
      values: info.recipe,
      source: ImportSource.exif,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeEditorPage(
          library: library,
          recipe: imported.recipe,
          isNew: true,
          note: imported.note,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = entry.photo.info ?? const PhotoInfo();
    final recipe = info.recipe;
    final rows = <(String, String)>[
      ('촬영 시각', formatShotAt(info) ?? '알 수 없음'),
      (
        '장소',
        switch (entry.place?.parts) {
          final parts? when parts.isNotEmpty => parts.join(' '),
          _ => info.location == null ? '위치 없음' : '장소 이름을 아직 받지 않음',
        },
      ),
      (
        '기종',
        [
          ?info.model,
          if (info.imageCount case final count?) '촬영 번호 $count',
        ].join(' · '),
      ),
      for (final field in recipeFields)
        if (recipe[field.id] case final value? when isApplicable(field, recipe))
          (field.label, field.display(value)),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(entry.photo.file.name)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton.icon(
            onPressed: recipe.isEmpty
                ? null
                : () => _importRecipe(context, info),
            icon: const Icon(Icons.download_outlined),
            label: const Text('레시피로 가져오기'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          FutureBuilder(
            future: _image,
            builder: (context, snapshot) => SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.4,
              child: switch (snapshot.data) {
                final bytes? => Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  cacheWidth: 2048,
                  errorBuilder: (_, _, _) => const _NoImage(),
                ),
                null =>
                  snapshot.connectionState == ConnectionState.done
                      ? const _NoImage()
                      : const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      label,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                  Expanded(child: Text(value)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.surfaceRaised,
    child: Center(child: Text('사진을 열 수 없습니다')),
  );
}
