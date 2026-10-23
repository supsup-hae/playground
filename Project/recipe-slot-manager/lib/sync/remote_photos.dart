import 'package:recipe_slot_manager/photo/photo_info.dart';
import 'package:recipe_slot_manager/photo/place_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 원격에 두는 사진 한 장: 같은 사진 키, 파일 이름, 촬영 정보. 사진 파일은 올리지 않는다.
final class RemotePhoto {
  const RemotePhoto({
    required this.key,
    required this.name,
    required this.info,
  });

  /// 형식이 맞지 않으면 [FormatException].
  factory RemotePhoto.fromJson(Object? json) {
    if (json
        case {
          'key': final String key,
          'name': final String name,
          'info': final Object? info,
        }
        when key.isNotEmpty) {
      return RemotePhoto(key: key, name: name, info: PhotoInfo.fromJson(info));
    }
    throw FormatException('원격 사진 형식 오류', json);
  }

  /// `PhotoIndexStore.photoKey`.
  final String key;
  final String name;
  final PhotoInfo info;

  Map<String, Object?> toJson() => {
    'key': key,
    'name': name,
    'info': info.toJson(),
  };
}

/// 로그인한 사용자의 원격 사진 색인과 세트 저장 기록.
abstract interface class RemotePhotos {
  /// 모든 사진 행의 body. 형식 검사는 받는 쪽이 한다.
  Future<List<Object?>> fetchPhotos();

  /// 키가 같은 행은 덮어쓴다.
  Future<void> upsertPhotos(List<RemotePhoto> photos);

  /// 모든 기록 행의 body.
  Future<List<Object?>> fetchLogs();

  /// id 가 같은 행은 덮어쓴다.
  Future<void> upsertLogs(List<PlaceLog> logs);
}

/// `supabase/photo-log.sql` 의 `photos`·`place_logs` 테이블을 쓰는 구현. 행의 `user_id` 는
/// 서버 기본값(auth.uid())과 RLS 가 정한다.
class SupabaseRemotePhotos implements RemotePhotos {
  SupabaseRemotePhotos(this._client);

  final SupabaseClient _client;

  /// PostgREST 가 한 번에 돌려주는 최대 행 수. 올릴 때도 이만큼씩 나눈다.
  static const _pageSize = 1000;

  @override
  Future<List<Object?>> fetchPhotos() => _bodies('photos', 'key');

  @override
  Future<List<Object?>> fetchLogs() => _bodies('place_logs', 'id');

  Future<List<Object?>> _bodies(String table, String orderBy) async {
    final bodies = <Object?>[];
    for (var from = 0; ; from += _pageSize) {
      final rows = await _client
          .from(table)
          .select('body')
          .order(orderBy)
          .range(from, from + _pageSize - 1);
      bodies.addAll([for (final row in rows) row['body']]);
      if (rows.length < _pageSize) return bodies;
    }
  }

  @override
  Future<void> upsertPhotos(List<RemotePhoto> photos) async {
    if (photos.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    for (var from = 0; from < photos.length; from += _pageSize) {
      await _client.from('photos').upsert([
        for (final photo in photos.skip(from).take(_pageSize))
          {'key': photo.key, 'body': photo.toJson(), 'updated_at': now},
      ], onConflict: 'user_id,key');
    }
  }

  @override
  Future<void> upsertLogs(List<PlaceLog> logs) async {
    if (logs.isEmpty) return;
    await _client.from('place_logs').upsert([
      for (final log in logs)
        {
          'id': log.id,
          'body': log.toJson(),
          'logged_at': log.loggedAt.toUtc().toIso8601String(),
        },
    ], onConflict: 'user_id,id');
  }
}
