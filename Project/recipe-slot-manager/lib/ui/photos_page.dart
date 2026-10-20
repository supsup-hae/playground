import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/photo/photo_index_store.dart';
import 'package:recipe_slot_manager/photo/photo_indexer.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/recipe/recipe_fields.dart';

/// 사진 화면에 필요한 것. [addSource] 는 플랫폼마다 다르다(macOS 폴더 고르기, Android 앨범
/// 선택). [allowLocation] 은 Android 에서 사진 위치 권한을 다시 요청한다.
typedef PhotosSetup = ({
  PhotoIndexStore store,
  PhotoIndexer indexer,
  Future<PhotoSource?> Function(BuildContext context) addSource,
  Future<void> Function()? allowLocation,
});

/// 사진 출처 등록, 새 사진 읽기, 색인 요약.
class PhotosPage extends StatefulWidget {
  const PhotosPage({super.key, required this.setup});

  final PhotosSetup setup;

  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  PhotoIndexStore get _store => widget.setup.store;

  void _tell(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _add() async {
    final PhotoSource? source;
    try {
      source = await widget.setup.addSource(context);
    } on PhotoSourceException catch (e) {
      return _tell(e.message);
    }
    if (source == null || !mounted) return;
    final duplicate = _store.sources.any(
      (s) => s.kind == source!.kind && s.location == source.location,
    );
    if (duplicate) return _tell('이미 추가한 출처입니다');
    await _store.saveSource(source);
  }

  Future<void> _remove(PhotoSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${source.name} 빼기'),
        content: const Text('목록과 색인에서만 빼고 사진 파일은 지우지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('빼기'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _store.removeSource(source.id);
  }

  Future<void> _indexAll() async {
    final failures = await widget.setup.indexer.indexAll();
    if (mounted && failures.isNotEmpty) _tell(failures.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_store, widget.setup.indexer]),
      builder: (context, _) {
        final sources = _store.sources;
        final summary = _store.summary;
        final redacted = _store.photos.any((p) => p.locationRedacted);
        final progress = widget.setup.indexer.progress;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                const Expanded(child: Text('사진 출처', style: AppType.label)),
                TextButton.icon(
                  onPressed: progress == null ? _add : null,
                  icon: const Icon(Icons.add),
                  label: const Text('추가'),
                ),
              ],
            ),
            if (sources.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  '사진 폴더를 추가하세요. 휴대폰에서는 XApp 앨범을 고르면 됩니다.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            for (final source in sources) _sourceTile(source, progress == null),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: sources.isNotEmpty && progress == null
                  ? _indexAll
                  : null,
              child: const Text('새 사진 읽기'),
            ),
            if (progress != null) ...[
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(
                value: progress.total == 0
                    ? null
                    : progress.done / progress.total,
              ),
              Text(
                '${progress.name} ${progress.done} / ${progress.total}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
            if (redacted) ...[
              const SizedBox(height: AppSpacing.md),
              _locationNotice(),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              '전체 ${summary.total}장 · 위치 있음 ${summary.withLocation}장 · '
              '읽지 못함 ${summary.failed}장',
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final MapEntry(key: code, value: count)
                    in summary.byFilmSimulation.entries)
                  Chip(
                    label: Text(
                      '${fieldById['filmSimulation']!.display(code.toDouble())} $count',
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _sourceTile(PhotoSource source, bool enabled) {
    final count = _store.photosOf(source.id).length;
    final kind = switch (source.kind) {
      PhotoSourceKind.folder => '폴더',
      PhotoSourceKind.album => '앨범',
    };
    final indexedAt = source.indexedAt?.toLocal();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        source.kind == PhotoSourceKind.folder
            ? Icons.folder_outlined
            : Icons.photo_album_outlined,
      ),
      title: Text(source.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        indexedAt == null
            ? '$kind · 아직 읽지 않음'
            : '$kind · $count장 · ${_date(indexedAt)} 읽음',
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: '목록에서 빼기',
        onPressed: enabled ? () => _remove(source) : null,
        icon: const Icon(Icons.remove_circle_outline),
      ),
    );
  }

  Widget _locationNotice() {
    final allow = widget.setup.allowLocation;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '사진 위치 접근이 허용되지 않아 위치를 읽을 수 없습니다. '
              '허용한 뒤 새 사진 읽기를 다시 누르세요.',
            ),
          ),
          if (allow != null)
            TextButton(onPressed: allow, child: const Text('허용')),
        ],
      ),
    );
  }

  static String _date(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
