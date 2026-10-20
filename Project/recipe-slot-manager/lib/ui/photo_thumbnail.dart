import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/import/jpeg_exif.dart';
import 'package:recipe_slot_manager/photo/photo_indexer.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';

/// 사진의 EXIF 썸네일(카메라가 넣은 작은 JPEG)을 앞부분 읽기로 꺼내 둔다. 최근 [capacity] 장만
/// 기억한다.
class PhotoThumbnails {
  PhotoThumbnails(this.indexer, {this.capacity = 500});

  final PhotoIndexer indexer;
  final int capacity;

  /// 넣은 순서를 지키는 맵이라 맨 앞이 가장 오래 쓰지 않은 썸네일이다.
  final _cache = <String, Future<Uint8List?>>{};

  /// 썸네일이 없거나 사진을 읽지 못하면 null. 파일 크기·수정 시각이 바뀌면 다시 읽고, 읽지
  /// 못한 사진은 기억하지 않아 다음에 다시 읽는다.
  Future<Uint8List?> of(IndexedPhoto photo) {
    final file = photo.file;
    final key = '${photo.sourceId}|${file.id}|${file.size}|${file.modifiedMs}';
    final cached = _cache.remove(key);
    final future = cached ?? _load(photo, key);
    _cache[key] = future;
    if (_cache.length > capacity) _cache.remove(_cache.keys.first);
    return future;
  }

  Future<Uint8List?> _load(IndexedPhoto photo, String key) async {
    final source = indexer.store.sourceById(photo.sourceId);
    final reader = source == null ? null : indexer.readers[source.kind];
    if (source == null || reader == null) return null;
    try {
      return readExifThumbnail(
        (await reader.readHead(source, photo.file)).bytes,
      );
    } on PhotoSourceException {
      _cache.remove(key);
      return null;
    }
  }
}

/// 정사각형 썸네일 칸. 썸네일이 없으면 사진 아이콘.
class PhotoThumbnail extends StatelessWidget {
  const PhotoThumbnail({
    super.key,
    required this.photo,
    required this.thumbnails,
    this.onTap,
  });

  final IndexedPhoto photo;
  final PhotoThumbnails thumbnails;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: AppColors.surfaceRaised,
      child: Center(
        child: Icon(Icons.photo_outlined, color: AppColors.textMuted),
      ),
    );
    return Semantics(
      button: true,
      label: photo.file.name,
      child: InkWell(
        key: ValueKey('photo-${photo.file.id}'),
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: FutureBuilder(
            future: thumbnails.of(photo),
            builder: (context, snapshot) => switch (snapshot.data) {
              final bytes? => Image.memory(
                bytes,
                fit: BoxFit.cover,
                cacheWidth: 320,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => placeholder,
              ),
              null => placeholder,
            },
          ),
        ),
      ),
    );
  }
}
