import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/camera/camera_session.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/ui/design_gallery_page.dart';
import 'package:recipe_slot_manager/ui/loadout_list_page.dart';
import 'package:recipe_slot_manager/ui/log_panel.dart';
import 'package:recipe_slot_manager/ui/recipe_list_page.dart';
import 'package:recipe_slot_manager/ui/slots_page.dart';

/// 왼쪽 탐색, 위쪽 카메라 연결 막대, 아래쪽 작업 로그로 된 앱의 바깥 틀.
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

  @override
  Widget build(BuildContext context) {
    final page = switch (_index) {
      0 => RecipeListPage(library: widget.library),
      1 => LoadoutListPage(library: widget.library, session: widget.session),
      2 => SlotsPage(session: widget.session),
      _ => const DesignGalleryPage(),
    };
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.tune),
                label: Text('레시피'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.view_week_outlined),
                label: Text('묶음'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.table_chart_outlined),
                label: Text('원시 값'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.palette_outlined),
                label: Text('디자인'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                CameraBar(
                  session: widget.session,
                  actions: widget.headerActions,
                ),
                const Divider(height: 1),
                Expanded(child: page),
                LogPanel(log: widget.session.log),
              ],
            ),
          ),
        ],
      ),
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
            Text(session.model ?? '카메라 없음'),
            const Spacer(),
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
    );
  }
}
