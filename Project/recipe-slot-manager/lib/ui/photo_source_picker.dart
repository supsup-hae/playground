import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:recipe_slot_manager/photo/album_reader.dart';
import 'package:recipe_slot_manager/photo/folder_reader.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';

/// 폴더를 골라 출처로 만든다. [useBookmarks] 면(macOS) 다음 실행에서도 읽도록 북마크를 저장한다.
Future<PhotoSource?> pickFolderSource({required bool useBookmarks}) async {
  final path = await getDirectoryPath(confirmButtonText: '선택');
  if (path == null) return null;
  return folderSource(path, useBookmarks: useBookmarks);
}

/// 사진 권한을 받은 뒤 앨범 목록에서 골라 출처로 만든다. 고르지 않으면 null.
Future<PhotoSource?> pickAlbumSource(
  BuildContext context,
  AlbumReader reader,
) async {
  final access = await reader.requestAccess();
  if (!access.images) {
    throw const PhotoSourceException('사진 접근이 허용되지 않았습니다');
  }
  final albums = await reader.albums();
  if (!context.mounted) return null;
  final album = await showDialog<PhotoAlbum>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('앨범 선택'),
      children: [
        for (final album in albums)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, album),
            child: Text('${album.name} (${album.count}장)'),
          ),
      ],
    ),
  );
  if (album == null) return null;
  return PhotoSource(
    id: newRecipeId(),
    kind: PhotoSourceKind.album,
    name: album.name,
    location: album.id,
  );
}
