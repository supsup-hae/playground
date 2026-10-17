import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';
import 'package:recipe_slot_manager/recipe/recipe_fields.dart';
import 'package:recipe_slot_manager/ui/recipe_editor_page.dart';

/// 보관함의 레시피 목록. 누르면 편집한다.
class RecipeListPage extends StatelessWidget {
  const RecipeListPage({super.key, required this.library});

  final LibraryStore library;

  void _open(BuildContext context, Recipe recipe, {required bool isNew}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RecipeEditorPage(library: library, recipe: recipe, isNew: isNew),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final recipes = library.recipes;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Text('레시피 ${recipes.length}개', style: AppType.label),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _open(
                      context,
                      Recipe(
                        id: newRecipeId(),
                        name: '새 레시피',
                        values: const {},
                        updatedAt: DateTime.now().toUtc(),
                      ),
                      isNew: true,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('새 레시피'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: recipes.isEmpty
                  ? const Center(child: Text('레시피가 없다'))
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      children: [
                        for (final recipe in recipes)
                          Card(
                            child: ListTile(
                              title: Text(recipe.name),
                              subtitle: Text(_summary(recipe)),
                              onTap: () => _open(context, recipe, isNew: false),
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

  String _summary(Recipe recipe) => [
    switch (recipe.values['filmSimulation']) {
      final code? => fieldById['filmSimulation']!.display(code),
      null => '필름 시뮬레이션 유지',
    },
    ...recipe.tags.map((t) => '#$t'),
  ].join('  ');
}
