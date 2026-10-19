import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/sync/sync_service.dart';
import 'package:recipe_slot_manager/ui/sign_in_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 셸 상단의 동기화 버튼. 설정이 없으면 비활성, 로그인 전이면 로그인 버튼을 보인다.
class SyncBar extends StatelessWidget {
  const SyncBar({super.key, required this.sync, required this.auth});

  /// Supabase 설정이 없으면 둘 다 null.
  final SyncService? sync;
  final GoTrueClient? auth;

  @override
  Widget build(BuildContext context) {
    final sync = this.sync;
    final auth = this.auth;
    if (sync == null || auth == null) {
      return const Tooltip(
        message: '--dart-define-from-file=supabase.json 으로 실행하면 보관함이 동기화됩니다',
        child: TextButton(onPressed: null, child: Text('동기화 설정 없음')),
      );
    }
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        if (auth.currentSession == null) {
          return TextButton(
            onPressed: () async {
              final signedIn = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => SignInPage(auth: auth)),
              );
              if (signedIn ?? false) await sync.sync();
            },
            child: const Text('로그인'),
          );
        }
        return ListenableBuilder(
          listenable: sync,
          builder: (context, _) => OutlinedButton.icon(
            onPressed: sync.syncing ? null : sync.sync,
            icon: const Icon(Icons.sync, size: 18),
            label: Text(switch (sync.lastSyncAt) {
              final at? =>
                '동기화됨 ${at.toLocal().toIso8601String().substring(11, 16)}',
              null => '동기화',
            }),
          ),
        );
      },
    );
  }
}
