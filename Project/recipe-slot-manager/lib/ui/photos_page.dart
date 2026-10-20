import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/photo/photo_query.dart';
import 'package:recipe_slot_manager/ui/photo_detail_page.dart';
import 'package:recipe_slot_manager/ui/photo_list_view.dart';
import 'package:recipe_slot_manager/ui/photo_map_view.dart';
import 'package:recipe_slot_manager/ui/photo_sources_panel.dart';
import 'package:recipe_slot_manager/ui/photos_setup.dart';
import 'package:recipe_slot_manager/ui/place_log_list_view.dart';

enum _View { list, map, logs }

/// 사진 찾기: 목록·지도·기록 전환, 검색어, 연도·지역·위치 없음·필름 시뮬레이션 필터.
/// 기록은 세트 저장 기록이며 연도·지역·검색어만 쓴다. 지도에는 기록 점을 겹칠 수 있다.
/// 출처 관리는 오른쪽 위 버튼의 시트에 있다.
class PhotosPage extends StatefulWidget {
  const PhotosPage({super.key, required this.setup, required this.library});

  final PhotosSetup setup;
  final LibraryStore library;

  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  var _view = _View.list;
  var _logsOnMap = false;
  late final _search = TextEditingController(text: _filter.value.text);

  PhotosSetup get _setup => widget.setup;
  ValueNotifier<PhotoFilter> get _filter => _setup.filter;

  void _update(PhotoFilter Function(PhotoFilter f) change) =>
      _filter.value = change(_filter.value);

  void _open(PhotoEntry entry) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          PhotoDetailPage(entry: entry, setup: _setup, library: widget.library),
    ),
  );

  void _openSources() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // 시트 안의 알림이 시트 뒤에 가리지 않도록 시트에 따로 메신저를 둔다.
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: PhotoSourcesPanel(setup: _setup),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _setup.store,
        _setup.places,
        _setup.indexer,
        _setup.logs,
        _filter,
      ]),
      builder: (context, _) {
        final filter = _filter.value;
        final photos = _setup.store.photos;
        final logs = _setup.logs.logs;
        final showLogs = _view == _View.logs;
        final entries = queryPhotos(photos, _setup.places, filter);
        final logEntries = queryPlaceLogs(logs, _setup.places, filter);
        final facets = showLogs
            ? placeLogFacets(logs, _setup.places, filter)
            : photoFacets(photos, _setup.places, filter);
        final noLocation = photos
            .where((p) => p.info != null && p.info!.location == null)
            .length;
        final progress = _setup.indexer.progress;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                0,
              ),
              child: Row(
                children: [
                  SegmentedButton<_View>(
                    segments: const [
                      ButtonSegment(
                        value: _View.list,
                        icon: Icon(Icons.grid_view),
                        label: Text('목록'),
                      ),
                      ButtonSegment(
                        value: _View.map,
                        icon: Icon(Icons.map_outlined),
                        label: Text('지도'),
                      ),
                      ButtonSegment(
                        value: _View.logs,
                        icon: Icon(Icons.history),
                        label: Text('기록'),
                      ),
                    ],
                    selected: {_view},
                    onSelectionChanged: (s) => setState(() => _view = s.first),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '사진 출처',
                    onPressed: _openSources,
                    icon: const Icon(Icons.folder_open_outlined),
                  ),
                ],
              ),
            ),
            if (progress != null) ...[
              LinearProgressIndicator(
                value: progress.total == 0
                    ? null
                    : progress.done / progress.total,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  '${progress.name} ${progress.done} / ${progress.total}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: showLogs ? '장소·세트·레시피 검색' : '장소·파일·시뮬레이션 검색',
                  isDense: true,
                ),
                onChanged: (text) => _update((f) => f.copyWith(text: text)),
              ),
            ),
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                children: [
                  _yearMenu(filter, facets),
                  const SizedBox(width: AppSpacing.sm),
                  _regionMenu(filter, facets),
                  if (_view == _View.map) ...[
                    const SizedBox(width: AppSpacing.sm),
                    FilterChip(
                      label: Text(
                        '세트 저장 위치 '
                        '${logEntries.where((e) => e.log.location != null).length}',
                      ),
                      selected: _logsOnMap,
                      onSelected: (on) => setState(() => _logsOnMap = on),
                    ),
                  ],
                  if (!showLogs) ...[
                    const SizedBox(width: AppSpacing.sm),
                    FilterChip(
                      label: Text('위치 없음 $noLocation'),
                      selected: filter.noLocationOnly,
                      onSelected: (on) =>
                          _update((f) => f.copyWith(noLocationOnly: on)),
                    ),
                  ],
                  for (final MapEntry(key: code, value: count)
                      in facets.films.entries) ...[
                    const SizedBox(width: AppSpacing.sm),
                    FilterChip(
                      label: Text('${filmName(code)} $count'),
                      selected: filter.films.contains(code),
                      onSelected: (on) => _update(
                        (f) => f.copyWith(
                          films: on
                              ? {...f.films, code}
                              : ({...f.films}..remove(code)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                showLogs
                    ? '기록 ${logEntries.length}개 · 위치 없음 '
                          '${logEntries.where((e) => e.log.location == null).length}개'
                    : '${entries.length}장 · 위치 없음 '
                          '${entries.where((e) => e.photo.info?.location == null).length}장',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            Expanded(child: _body(entries, logEntries)),
          ],
        );
      },
    );
  }

  Widget _body(List<PhotoEntry> entries, List<PlaceLogEntry> logs) {
    if (_view == _View.logs) {
      if (_setup.logs.logs.isEmpty) {
        return const _Message('세트를 카메라에 저장하면 여기에 기록됩니다');
      }
      if (logs.isEmpty) return const _Message('조건에 맞는 기록이 없습니다');
      return PlaceLogListView(entries: logs);
    }
    if (_setup.store.sources.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _openSources,
          icon: const Icon(Icons.add),
          label: const Text('사진 출처를 추가하세요'),
        ),
      );
    }
    final mapLogs = _logsOnMap ? logs : const <PlaceLogEntry>[];
    if (entries.isEmpty && (_view == _View.list || mapLogs.isEmpty)) {
      return const _Message('조건에 맞는 사진이 없습니다');
    }
    return switch (_view) {
      _View.list => PhotoListView(
        entries: entries,
        thumbnails: _setup.thumbnails,
        onOpen: _open,
      ),
      _View.map => PhotoMapView(
        // 조건이나 기록 겹치기가 바뀌면 찾은 점에 맞춰 화면을 다시 맞춘다.
        key: ValueKey((_filter.value, _logsOnMap)),
        entries: entries,
        logs: mapLogs,
        thumbnails: _setup.thumbnails,
        onOpen: _open,
        tiles: _setup.mapTiles,
      ),
      _View.logs => throw StateError('기록 보기는 위에서 처리한다'),
    };
  }

  /// "모든 연도" 메뉴 값. 메뉴는 null 값을 닫기로 처리하므로 쓰지 않는 연도로 나타낸다.
  static const _allYears = 0;

  Widget _yearMenu(PhotoFilter filter, PhotoFacets facets) =>
      PopupMenuButton<int>(
        tooltip: '연도',
        onSelected: (year) => _update(
          (f) => f.copyWith(year: () => year == _allYears ? null : year),
        ),
        itemBuilder: (_) => [
          const PopupMenuItem(value: _allYears, child: Text('모든 연도')),
          for (final year in facets.years)
            PopupMenuItem(value: year, child: Text('$year년')),
        ],
        child: Chip(
          avatar: const Icon(Icons.event, size: 18),
          label: Text(filter.year == null ? '연도' : '${filter.year}년'),
        ),
      );

  Widget _regionMenu(PhotoFilter filter, PhotoFacets facets) {
    final (choices, pick) = switch (filter) {
      PhotoFilter(country: null) => (
        facets.countries,
        (String v) => _update((f) => f.copyWith(country: () => v)),
      ),
      PhotoFilter(admin: null) => (
        facets.admins,
        (String v) => _update((f) => f.copyWith(admin: () => v)),
      ),
      PhotoFilter(locality: null) => (
        facets.localities,
        (String v) => _update((f) => f.copyWith(locality: () => v)),
      ),
      _ => (const <String>[], (String _) {}),
    };
    final label = [?filter.country, ?filter.admin, ?filter.locality];
    return PopupMenuButton<String>(
      tooltip: '지역',
      onSelected: (value) {
        if (value.isEmpty) {
          _update(
            (f) => f.copyWith(
              country: () => null,
              admin: () => null,
              locality: () => null,
            ),
          );
        } else {
          pick(value);
        }
      },
      itemBuilder: (_) => [
        for (final choice in choices)
          PopupMenuItem(value: choice, child: Text(choice)),
        if (filter.country != null)
          const PopupMenuItem(value: '', child: Text('지역 해제')),
      ],
      child: Chip(
        avatar: const Icon(Icons.place_outlined, size: 18),
        label: Text(label.isEmpty ? '지역' : label.join(' › ')),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(text, style: const TextStyle(color: AppColors.textMuted)),
  );
}
