import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/design/slot_badge.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/library/loadout.dart';

/// 묶음 하나를 편집한다: 이름과, 슬롯 1–7 마다 넣을 레시피(비우면 그대로).
class LoadoutEditorPage extends StatefulWidget {
  const LoadoutEditorPage({
    super.key,
    required this.library,
    required this.loadout,
    required this.isNew,
  });

  final LibraryStore library;
  final Loadout loadout;
  final bool isNew;

  @override
  State<LoadoutEditorPage> createState() => _LoadoutEditorPageState();
}

class _LoadoutEditorPageState extends State<LoadoutEditorPage> {
  late var _name = widget.loadout.name;
  late final _slots = [
    for (final id in widget.loadout.slots) widget.library.recipeById(id)?.id,
  ];

  Future<void> _save() async {
    final name = _name.trim();
    await widget.library.saveLoadout(
      widget.loadout.copyWith(
        name: name.isEmpty ? widget.loadout.name : name,
        slots: _slots,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await widget.library.deleteLoadout(widget.loadout.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final recipes = widget.library.recipes;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? '새 세트' : '세트 편집'),
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
          TextFormField(
            initialValue: _name,
            decoration: const InputDecoration(labelText: '이름'),
            onChanged: (v) => _name = v,
          ),
          const SizedBox(height: AppSpacing.xl),
          for (var i = 0; i < _slots.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  SlotBadge(slot: i + 1, active: _slots[i] != null),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButton<String?>(
                      key: ValueKey('slot-${i + 1}'),
                      isExpanded: true,
                      value: _slots[i],
                      onChanged: (id) => setState(() => _slots[i] = id),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('변경 없음 (비움)'),
                        ),
                        for (final recipe in recipes)
                          DropdownMenuItem(
                            value: recipe.id,
                            child: Text(recipe.name),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
