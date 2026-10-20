import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/photo/photo_query.dart';
import 'package:recipe_slot_manager/ui/photo_detail_page.dart';
import 'package:recipe_slot_manager/ui/photo_thumbnail.dart';

/// 찾은 사진을 촬영 날짜별로 묶어 썸네일 격자로 보인다. 날짜 줄에는 그날 사진의 도시 이름.
class PhotoListView extends StatelessWidget {
  const PhotoListView({
    super.key,
    required this.entries,
    required this.thumbnails,
    required this.onOpen,
  });

  final List<PhotoEntry> entries;
  final PhotoThumbnails thumbnails;
  final void Function(PhotoEntry entry) onOpen;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<PhotoEntry>>{};
    for (final entry in entries) {
      final shotAt = entry.photo.info?.shotAt;
      (groups[shotAt == null ? '날짜 없음' : formatDate(shotAt)] ??= []).add(entry);
    }
    final columns =
        MediaQuery.sizeOf(context).width < AppBreakpoints.compactWidth ? 3 : 6;
    return CustomScrollView(
      slivers: [
        for (final MapEntry(key: date, value: group) in groups.entries) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                [
                  date,
                  ...{
                    for (final e in group)
                      if (e.place?.cityLabel case final city?
                          when city.isNotEmpty)
                        city,
                  },
                ].join(' · '),
                style: AppType.label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverGrid.count(
              crossAxisCount: columns,
              mainAxisSpacing: AppSpacing.xs,
              crossAxisSpacing: AppSpacing.xs,
              children: [
                for (final entry in group)
                  PhotoThumbnail(
                    photo: entry.photo,
                    thumbnails: thumbnails,
                    onTap: () => onOpen(entry),
                  ),
              ],
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
      ],
    );
  }
}
