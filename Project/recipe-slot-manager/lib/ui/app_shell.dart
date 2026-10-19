import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/camera/camera_session.dart';
import 'package:recipe_slot_manager/camera/raw_developer.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/ui/design_gallery_page.dart';
import 'package:recipe_slot_manager/ui/loadout_list_page.dart';
import 'package:recipe_slot_manager/ui/log_panel.dart';
import 'package:recipe_slot_manager/ui/raw_preview_page.dart';
import 'package:recipe_slot_manager/ui/recipe_list_page.dart';
import 'package:recipe_slot_manager/ui/slots_page.dart';

/// 화면 목적지. 넓은 창의 레일과 좁은 화면의 아래 탭이 같은 목록을 쓴다.
const _destinations = [
  (Icons.tune, '레시피'),
  (Icons.view_week_outlined, '세트'),
  (Icons.table_chart_outlined, '사용자 설정'),
  (Icons.photo_filter_outlined, 'RAW 미리보기'),
  (Icons.palette_outlined, '디자인'),
];

/// 위쪽 카메라 연결 막대, 아래쪽 작업 로그, 화면 탐색으로 된 앱의 바깥 틀.
///
/// 휴대폰 배치([AppBreakpoints])에서는 아래 탭과 접힌 로그를 쓰고, 그 밖에는 왼쪽 레일과 펼친
/// 로그를 쓴다.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.session,
    required this.library,
    this.headerActions = const [],
    this.initialIndex = 0,
  });

  final CameraSession session;
  final LibraryStore library;

  /// 연결 버튼 앞에 놓을 버튼 (동기화 등).
  final List<Widget> headerActions;
  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late var _index = widget.initialIndex;

  /// 보낸 RAF 를 화면을 오가도 기억하도록 셸이 들고 있는다.
  late final _developer = RawDeveloper(widget.session.camera);

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact =
        size.width < AppBreakpoints.compactWidth ||
        size.height < AppBreakpoints.compactHeight;
    final page = switch (_index) {
      0 => RecipeListPage(library: widget.library, session: widget.session),
      1 => LoadoutListPage(library: widget.library, session: widget.session),
      2 => SlotsPage(session: widget.session),
      3 => RawPreviewPage(
        session: widget.session,
        library: widget.library,
        developer: _developer,
      ),
      _ => const DesignGalleryPage(),
    };
    final content = Column(
      children: [
        CameraBar(session: widget.session, actions: widget.headerActions),
        const Divider(height: 1),
        Expanded(child: page),
        LogPanel(log: widget.session.log, compact: compact),
      ],
    );

    // 배치가 바뀌어도 화면 상태가 남도록 본문은 늘 같은 자리(같은 키)에 둔다.
    return Scaffold(
      // 아래 탭일 때 아래 여백(제스처 막대)은 NavigationBar 가 맡는다.
      body: SafeArea(
        bottom: !compact,
        child: Row(
          children: [
            if (!compact) ...[
              NavigationRail(
                selectedIndex: _index,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: _select,
                destinations: [
                  for (final (icon, label) in _destinations)
                    NavigationRailDestination(
                      icon: Icon(icon),
                      label: Text(label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
            ],
            Expanded(key: const ValueKey('shell-content'), child: content),
          ],
        ),
      ),
      bottomNavigationBar: compact
          ? NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: [
                for (final (icon, label) in _destinations)
                  NavigationDestination(icon: Icon(icon), label: label),
              ],
            )
          : null,
    );
  }
}

/// 카메라 모델과 연결 버튼. 작업 중이면 진행 표시를 보인다.
class CameraBar extends StatelessWidget {
  const CameraBar({super.key, required this.session, this.actions = const []});

  final CameraSession session;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.camera_alt_outlined,
              color: session.connected ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                session.model ?? '카메라 연결 안 됨',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // 글꼴이 커서 버튼이 다 들어가지 않으면 가로로 밀어 볼 수 있게 한다.
            Flexible(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (session.busy)
                        const Padding(
                          padding: EdgeInsets.only(right: AppSpacing.md),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ...actions,
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        onPressed: session.connected || session.busy
                            ? null
                            : session.connect,
                        child: const Text('연결'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
