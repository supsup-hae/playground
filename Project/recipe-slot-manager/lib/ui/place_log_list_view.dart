import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/photo/photo_query.dart';
import 'package:recipe_slot_manager/photo/place.dart';
import 'package:recipe_slot_manager/ui/formats.dart';

/// 세트 저장 기록을 날짜별로 묶어 보인다. [entries] 는 최신순.
class PlaceLogListView extends StatelessWidget {
  const PlaceLogListView({super.key, required this.entries});

  final List<PlaceLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<PlaceLogEntry>>{};
    for (final entry in entries) {
      (groups[formatDate(entry.log.localTime)] ??= []).add(entry);
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        for (final MapEntry(key: date, value: group) in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(date, style: AppType.label),
          ),
          for (final entry in group) PlaceLogTile(entry: entry),
        ],
      ],
    );
  }
}

/// 기록 하나: 시각·세트 이름, 장소(없으면 좌표나 위치 없는 이유), 넣은 레시피 이름.
class PlaceLogTile extends StatelessWidget {
  const PlaceLogTile({super.key, required this.entry});

  final PlaceLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final (:log, :place) = entry;
    final location = log.location;
    final accuracy = log.accuracy;
    final where = location == null
        ? '위치 없음 (${log.missingReason ?? '이유 모름'})'
        : [
            switch (place) {
              final place? when !place.isEmpty => place.parts.join(' '),
              _ => formatGeoPoint(location),
            },
            if (accuracy != null) '(약 ${accuracy.round()} m)',
          ].join(' ');
    final slots = [
      for (var i = 0; i < log.slots.length; i++)
        if (log.slots[i] case final name?) 'C${i + 1} $name',
    ].join(' · ');
    return ListTile(
      leading: const Icon(Icons.view_week_outlined),
      title: Text('${formatTime(log.localTime)} · ${log.loadoutName}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(where),
          if (slots.isNotEmpty)
            Text(slots, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
