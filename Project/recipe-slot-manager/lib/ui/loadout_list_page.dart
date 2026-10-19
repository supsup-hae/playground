import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/camera/camera_session.dart';
import 'package:recipe_slot_manager/design/slot_badge.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/library/loadout.dart';
import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';
import 'package:recipe_slot_manager/ui/apply_loadout_page.dart';
import 'package:recipe_slot_manager/ui/loadout_editor_page.dart';

/// 상황별 묶음 목록. 편집하거나, 카메라와 비교한 뒤 7슬롯에 쓴다.
class LoadoutListPage extends StatelessWidget {
  const LoadoutListPage({
    super.key,
    required this.library,
    required this.session,
  });

  final LibraryStore library;
  final CameraSession session;

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final loadouts = library.loadouts;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Text('세트 ${loadouts.length}개', style: AppType.label),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _push(
                      context,
                      LoadoutEditorPage(
                        library: library,
                        loadout: Loadout(
                          id: newRecipeId(),
                          name: '새 세트',
                          slots: List.filled(FujiProp.slotCount, null),
                          updatedAt: DateTime.now().toUtc(),
                        ),
                        isNew: true,
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('새 세트'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: loadouts.isEmpty
                  ? const Center(child: Text('세트가 없습니다'))
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      children: [
                        for (final loadout in loadouts)
                          _LoadoutCard(
                            loadout: loadout,
                            library: library,
                            onEdit: () => _push(
                              context,
                              LoadoutEditorPage(
                                library: library,
                                loadout: loadout,
                                isNew: false,
                              ),
                            ),
                            onApply: () => _push(
                              context,
                              ApplyLoadoutPage(
                                session: session,
                                library: library,
                                loadout: loadout,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _LoadoutCard extends StatelessWidget {
  const _LoadoutCard({
    required this.loadout,
    required this.library,
    required this.onEdit,
    required this.onApply,
  });

  final Loadout loadout;
  final LibraryStore library;
  final VoidCallback onEdit;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final recipes = library.slotRecipes(loadout);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    loadout.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                OutlinedButton(onPressed: onEdit, child: const Text('편집')),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(onPressed: onApply, child: const Text('비교·저장')),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                for (var i = 0; i < recipes.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SlotBadge(slot: i + 1, active: recipes[i] != null),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        recipes[i]?.name ?? '변경 없음',
                        style: TextStyle(
                          color: recipes[i] == null
                              ? AppColors.textMuted
                              : AppColors.text,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
