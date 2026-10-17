/// `--dart-define-from-file=supabase.json` 으로 받는 Supabase 접속 정보.
/// 값이 비어 있으면 앱은 기기 저장만으로 동작한다.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');

  /// 공개 클라이언트용 publishable key (`sb_publishable_…`). secret·service_role 키는 넣지 않는다.
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
