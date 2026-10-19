import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/design/dial_scale.dart';
import 'package:recipe_slot_manager/design/knob_selector.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/ptp/ptp_string.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';
import 'package:recipe_slot_manager/recipe/recipe_fields.dart';
import 'package:recipe_slot_manager/util/step_value.dart';

/// 레시피 하나를 편집한다. 값을 정하지 않은 필드는 "카메라 값 유지"다.
/// 지금 필름 시뮬레이션·WB 에서 의미 없는 필드는 숨기고, 저장할 때도 뺀다.
class RecipeEditorPage extends StatefulWidget {
  const RecipeEditorPage({
    super.key,
    required this.library,
    required this.recipe,
    required this.isNew,
    this.note,
  });

  final LibraryStore library;
  final Recipe recipe;
  final bool isNew;

  /// 화면 위에 보일 안내 (가져온 출처와 읽은 항목 수).
  final String? note;

  @override
  State<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends State<RecipeEditorPage> {
  late var _name = widget.recipe.name;
  late var _tags = widget.recipe.tags.join(', ');
  late final _values = Map<String, double>.of(widget.recipe.values);

  void _set(RecipeField field, double? value) => setState(() {
    if (value == null) {
      _values.remove(field.id);
    } else {
      _values[field.id] = value;
    }
  });

  Future<void> _save() async {
    final name = _name.trim();
    await widget.library.saveRecipe(
      widget.recipe.copyWith(
        name: name.isEmpty ? widget.recipe.name : name,
        tags: [
          for (final tag in _tags.split(','))
            if (tag.trim().isNotEmpty) tag.trim(),
        ],
        values: {
          for (final MapEntry(:key, :value) in _values.entries)
            if (isApplicable(fieldById[key]!, _values)) key: value,
        },
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await widget.library.deleteRecipe(widget.recipe.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? '새 레시피' : '레시피 편집'),
        actions: [
          if (!widget.isNew)
            IconButton(
              tooltip: '삭제',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: FilledButton(onPressed: _save, child: const Text('저장')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          if (widget.note case final note?)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Text(
                note,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
          TextFormField(
            key: const ValueKey('recipe-name'),
            initialValue: _name,
            maxLength: maxPtpStringLength,
            decoration: const InputDecoration(labelText: '이름'),
            onChanged: (v) => _name = v,
          ),
          TextFormField(
            initialValue: _tags,
            decoration: const InputDecoration(labelText: '태그 (쉼표로 구분)'),
            onChanged: (v) => _tags = v,
          ),
          const SizedBox(height: AppSpacing.xl),
          for (final field in recipeFields)
            if (isApplicable(field, _values))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _FieldEditor(
                  field: field,
                  value: _values[field.id],
                  onChanged: (v) => _set(field, v),
                ),
              ),
        ],
      ),
    );
  }
}

class _FieldEditor extends StatelessWidget {
  const _FieldEditor({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final RecipeField field;
  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    if (value == null) {
      return Row(
        children: [
          Expanded(child: Text(field.label)),
          const Text('카메라 설정 유지', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            key: ValueKey('set-${field.id}'),
            onPressed: () => onChanged(_initialValue(field)),
            child: const Text('설정'),
          ),
        ],
      );
    }
    final editor = switch (field) {
      ChoiceField(:final choices) => KnobSelector<double>(
        label: field.label,
        options: [for (final (code, name) in choices) (code.toDouble(), name)],
        value: value,
        onChanged: onChanged,
      ),
      ScaleField(:final min, :final max, :final step) => DialScale(
        label: field.label,
        value: value,
        min: min,
        max: max,
        step: step,
        format: field.display,
        onChanged: onChanged,
      ),
      TableField(:final min, :final max, :final step) => DialScale(
        label: field.label,
        value: value,
        min: min,
        max: max,
        step: step,
        format: field.display,
        onChanged: onChanged,
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: editor),
        IconButton(
          tooltip: '카메라 설정 유지',
          onPressed: () => onChanged(null),
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    );
  }

  /// "설정"을 누를 때의 시작 값: 선택지는 첫 항목, 눈금은 0(범위 밖이면 가운데).
  static double _initialValue(RecipeField field) => switch (field) {
    ChoiceField(:final choices) => choices.first.$1.toDouble(),
    ScaleField(:final min, :final max, :final step) =>
      min <= 0 && max >= 0
          ? 0
          : snapToStep((min + max) / 2, min: min, max: max, step: step),
    TableField() => 0,
  };
}
