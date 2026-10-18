import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/camera/camera_session.dart';
import 'package:recipe_slot_manager/camera/raw_developer.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/import/file_pick.dart' as pick;
import 'package:recipe_slot_manager/library/library_store.dart';

/// 내 RAF 한 장에 레시피 A·B 를 적용해 카메라가 현상한 결과를 나란히 본다.
class RawPreviewPage extends StatefulWidget {
  const RawPreviewPage({
    super.key,
    required this.session,
    required this.library,
    required this.developer,
    this.pickRaf = pick.pickRaf,
  });

  final CameraSession session;
  final LibraryStore library;
  final RawDeveloper developer;
  final Future<pick.PickedFile?> Function() pickRaf;

  @override
  State<RawPreviewPage> createState() => _RawPreviewPageState();
}

/// 비교 화면과 확대 화면에서 결과 JPEG 를 풀어 그리는 폭. 4000만 화소 원본을 그대로 풀면
/// 한 장에 약 160 MB 를 쓴다.
const _previewWidth = 2048;
const _zoomWidth = 4096;

class _RawPreviewPageState extends State<RawPreviewPage> {
  /// 비교할 레시피 id. 키는 'a'·'b'.
  final _recipes = <String, String?>{'a': null, 'b': null};
  final _results = <String, Uint8List?>{'a': null, 'b': null};

  CameraSession get _session => widget.session;

  void _tell(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _loadRaf() async {
    if (!_session.connected) return _tell('카메라를 먼저 연결할 것');
    if (_session.busy) return _tell('카메라 작업이 끝난 뒤 다시 할 것');
    final file = await widget.pickRaf();
    if (file == null || !mounted) return;
    setState(() => _results.updateAll((_, _) => null));
    final failure = await _session.run(
      'RAF 보내기',
      () => widget.developer.loadRaf(file.bytes, name: file.name),
    );
    if (!mounted) return;
    if (failure != null) _tell(failure);
    setState(() {});
  }

  Future<void> _develop() async {
    for (final key in ['a', 'b']) {
      final recipe = widget.library.recipes
          .where((r) => r.id == _recipes[key])
          .firstOrNull;
      if (recipe == null) continue;
      Uint8List? jpeg;
      await _session.run('현상 ${key.toUpperCase()}', () async {
        jpeg = await widget.developer.develop(recipe.values);
      });
      if (!mounted) return;
      setState(() => _results[key] = jpeg);
    }
  }

  void _zoom(Uint8List jpeg) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(),
        body: InteractiveViewer(
          maxScale: 8,
          child: Center(child: Image.memory(jpeg, cacheWidth: _zoomWidth)),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < AppBreakpoints.compactWidth;
    return ListenableBuilder(
      listenable: Listenable.merge([_session, widget.library]),
      builder: (context, _) {
        final busy = _session.busy;
        final canDevelop =
            widget.developer.rafLoaded &&
            _recipes.values.any((id) => id != null) &&
            !busy;
        final pickers = [
          for (final key in ['a', 'b']) _recipePicker(key, busy),
        ];
        final results = [
          for (final key in ['a', 'b']) _result(key),
        ];
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : _loadRaf,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('RAF 고르기'),
                ),
                Text(
                  widget.developer.rafName == null
                      ? 'RAF 없음'
                      : '${widget.developer.rafName} (카메라에 보냄)',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (widget.library.recipes.isEmpty)
              const Text(
                '보관함에 레시피가 없다. 레시피 탭에서 만들거나 가져올 것',
                style: TextStyle(color: AppColors.textMuted),
              )
            else if (compact)
              ...pickers
            else
              Row(
                children: [
                  for (final picker in pickers) ...[
                    Expanded(child: picker),
                    const SizedBox(width: AppSpacing.md),
                  ],
                ],
              ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: canDevelop ? _develop : null,
                child: const Text('현상'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (compact)
              for (final result in results) ...[
                result,
                const SizedBox(height: AppSpacing.md),
              ]
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final result in results) ...[
                    Expanded(child: result),
                    const SizedBox(width: AppSpacing.md),
                  ],
                ],
              ),
            const Text(
              '현상은 카메라가 한다. X-T5 실기기에서 확인하지 않았다',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        );
      },
    );
  }

  Widget _recipePicker(String key, bool busy) {
    final recipes = widget.library.recipes;
    final selected = recipes.any((r) => r.id == _recipes[key])
        ? _recipes[key]
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(key.toUpperCase(), style: AppType.label),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: DropdownButton<String>(
              key: ValueKey('recipe-$key'),
              value: selected,
              isExpanded: true,
              hint: const Text('레시피 고르기'),
              onChanged: busy
                  ? null
                  : (id) => setState(() => _recipes[key] = id),
              items: [
                for (final recipe in recipes)
                  DropdownMenuItem(
                    value: recipe.id,
                    child: Text(recipe.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _result(String key) {
    final jpeg = _results[key];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(key.toUpperCase(), style: AppType.label),
        const SizedBox(height: AppSpacing.sm),
        if (jpeg == null)
          const _Placeholder('아직 없음')
        else
          Semantics(
            container: true,
            button: true,
            label: '결과 ${key.toUpperCase()} 크게 보기',
            child: GestureDetector(
              key: ValueKey('result-$key'),
              onTap: () => _zoom(jpeg),
              child: Image.memory(
                jpeg,
                cacheWidth: _previewWidth,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const _Placeholder('이미지를 열지 못했다'),
              ),
            ),
          ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    height: 160,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.line),
    ),
    child: Text(message, style: const TextStyle(color: AppColors.textMuted)),
  );
}
