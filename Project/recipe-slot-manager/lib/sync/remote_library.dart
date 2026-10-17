import 'package:recipe_slot_manager/library/loadout.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 원격에서 받은 행의 body. 형식 검사는 동기화 서비스가 한다.
final class RemoteChanges {
  const RemoteChanges({required this.recipes, required this.loadouts});

  final List<Object?> recipes;
  final List<Object?> loadouts;
}

/// 로그인한 사용자의 원격 보관함.
abstract interface class RemoteLibrary {
  /// 사용자의 모든 행. 삭제 표시가 있는 행도 포함한다.
  Future<RemoteChanges> fetchAll();

  /// id 가 같은 행은 덮어쓴다.
  Future<void> upsert({
    required List<Recipe> recipes,
    required List<Loadout> loadouts,
  });
}

/// `supabase/setup.sql` 의 `recipes`·`loadouts` 테이블을 쓰는 구현. 행의 `user_id` 는
/// 서버 기본값(auth.uid())과 RLS 가 정한다.
class SupabaseRemoteLibrary implements RemoteLibrary {
  SupabaseRemoteLibrary(this._client);

  final SupabaseClient _client;

  /// PostgREST 가 한 번에 돌려주는 최대 행 수.
  static const _pageSize = 1000;

  @override
  Future<RemoteChanges> fetchAll() async => RemoteChanges(
    recipes: await _bodies('recipes'),
    loadouts: await _bodies('loadouts'),
  );

  Future<List<Object?>> _bodies(String table) async {
    final bodies = <Object?>[];
    for (var from = 0; ; from += _pageSize) {
      final rows = await _client
          .from(table)
          .select('body')
          .order('id')
          .range(from, from + _pageSize - 1);
      bodies.addAll([for (final row in rows) row['body']]);
      if (rows.length < _pageSize) return bodies;
    }
  }

  @override
  Future<void> upsert({
    required List<Recipe> recipes,
    required List<Loadout> loadouts,
  }) async {
    if (recipes.isNotEmpty) {
      await _client.from('recipes').upsert([
        for (final r in recipes)
          _row(r.id, r.toJson(), r.updatedAt, r.deletedAt),
      ], onConflict: 'user_id,id');
    }
    if (loadouts.isNotEmpty) {
      await _client.from('loadouts').upsert([
        for (final l in loadouts)
          _row(l.id, l.toJson(), l.updatedAt, l.deletedAt),
      ], onConflict: 'user_id,id');
    }
  }

  static Map<String, Object?> _row(
    String id,
    Map<String, dynamic> body,
    DateTime updatedAt,
    DateTime? deletedAt,
  ) => {
    'id': id,
    'body': body,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
  };
}
