import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/import/jpeg_exif.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';

/// macOS 보안 범위 북마크 채널. `macos/Runner/BookmarkChannel.swift` 가 받는다.
const bookmarkChannel = MethodChannel('recipe_slot_manager/bookmarks');

const _jpegExtensions = {'.jpg', '.jpeg'};

/// [path] 폴더를 출처로 만든다. [useBookmarks] 면 다음 실행에서도 읽도록 북마크를 함께 저장한다.
Future<PhotoSource> folderSource(
  String path, {
  required bool useBookmarks,
  String? id,
}) async {
  String? bookmark;
  if (useBookmarks) {
    final bytes = await _call<Uint8List>('create', path);
    bookmark = base64Encode(bytes);
  }
  return PhotoSource(
    id: id ?? newRecipeId(),
    kind: PhotoSourceKind.folder,
    name: p.basename(path),
    location: path,
    bookmark: bookmark,
  );
}

/// 폴더 출처를 읽는다. 하위 폴더까지 `.jpg`·`.jpeg` 를 찾고, 이름이 `.` 으로 시작하는 파일과
/// 폴더는 뺀다.
class FolderReader implements PhotoSourceReader {
  FolderReader({this.useBookmarks = false, this.onSourceRenewed});

  /// macOS 샌드박스에서 고른 폴더는 북마크로만 다시 열 수 있다.
  final bool useBookmarks;

  /// 북마크가 오래되어 새로 만들었을 때 출처를 저장하게 한다.
  final Future<void> Function(PhotoSource renewed)? onSourceRenewed;

  /// 출처 id → 북마크를 풀어 얻은 경로. 접근은 [close] 까지 열어 둔다.
  final _opened = <String, String>{};

  /// 여는 중인 출처. 동시에 읽는 사진들이 같은 열기를 기다린다.
  final _opening = <String, Future<String>>{};

  @override
  Future<List<PhotoFile>> list(PhotoSource source) async {
    final root = Directory(await _open(source));
    if (!await root.exists()) {
      throw PhotoSourceException('폴더를 찾을 수 없습니다: ${source.name}');
    }
    final files = <PhotoFile>[];
    try {
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final relative = p.relative(entity.path, from: root.path);
        if (p.split(relative).any((part) => part.startsWith('.'))) continue;
        if (!_jpegExtensions.contains(p.extension(relative).toLowerCase())) {
          continue;
        }
        final stat = await entity.stat();
        // 훑는 사이 지워진 파일은 뺀다.
        if (stat.type == FileSystemEntityType.notFound) continue;
        files.add((
          id: relative,
          name: p.basename(relative),
          size: stat.size,
          modifiedMs: stat.modified.millisecondsSinceEpoch,
        ));
      }
    } on FileSystemException catch (e) {
      throw PhotoSourceException(
        '폴더를 읽지 못했습니다: ${source.name} (${e.message}, ${e.path})',
      );
    }
    return files;
  }

  @override
  Future<PhotoHead> readHead(
    PhotoSource source,
    PhotoFile file, {
    int length = jpegHeadBytes,
  }) async {
    // 색인 뒤 닫은 출처는 다시 연다. 접근은 다음 [close] 까지 열어 둔다.
    final base =
        _opened[source.id] ??
        await (_opening[source.id] ??= _open(source).whenComplete(() {
          // remove 가 돌려주는 Future(이 열기 자신)를 기다리지 않도록 값을 돌려주지 않는다.
          _opening.remove(source.id);
        }));
    final path = p.join(base, file.id);
    try {
      final handle = await File(path).open();
      try {
        return (bytes: await handle.read(length), locationRedacted: false);
      } finally {
        await handle.close();
      }
    } on FileSystemException catch (e) {
      throw PhotoSourceException('사진을 읽지 못했습니다: ${file.name} (${e.message})');
    }
  }

  @override
  Future<void> close(PhotoSource source) async {
    if (_opened.remove(source.id) case final path?) {
      await _call<void>('stop', path);
    }
  }

  Future<String> _open(PhotoSource source) async {
    final bookmark = source.bookmark;
    if (!useBookmarks || bookmark == null) return source.location;
    await close(source);
    final resolved = await _call<Map<Object?, Object?>>(
      'resolve',
      base64Decode(bookmark),
    );
    final path = resolved['path'] as String;
    _opened[source.id] = path;
    if (resolved['bookmark'] case final Uint8List renewed) {
      await onSourceRenewed?.call(
        source.copyWith(location: path, bookmark: base64Encode(renewed)),
      );
    }
    return path;
  }
}

Future<T> _call<T>(String method, Object? arguments) async {
  try {
    return await bookmarkChannel.invokeMethod<T>(method, arguments) as T;
  } on PlatformException catch (e) {
    throw PhotoSourceException('폴더에 접근하지 못했습니다: ${e.message ?? e.code}');
  } on MissingPluginException {
    throw const PhotoSourceException('이 기기에서는 폴더 접근을 유지할 수 없습니다');
  }
}
