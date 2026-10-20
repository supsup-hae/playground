import 'package:file_selector/file_selector.dart';
import 'package:recipe_slot_manager/photo/folder_reader.dart';
import 'package:recipe_slot_manager/photo/media_folder_reader.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/recipe/recipe.dart';

/// 폴더를 골라 출처로 만든다. [useBookmarks] 면(macOS) 다음 실행에서도 읽도록 북마크를 저장한다.
Future<PhotoSource?> pickFolderSource({required bool useBookmarks}) async {
  final path = await getDirectoryPath(confirmButtonText: '선택');
  if (path == null) return null;
  return folderSource(path, useBookmarks: useBookmarks);
}

/// 사진 권한을 받은 뒤 시스템 폴더 선택 창에서 휴대폰 폴더를 골라 출처로 만든다. 닫으면 null.
Future<PhotoSource?> pickMediaFolderSource(MediaFolderReader reader) async {
  final access = await reader.requestAccess();
  if (!access.images) {
    throw const PhotoSourceException('사진 접근이 허용되지 않았습니다');
  }
  final folder = await reader.pickFolder();
  if (folder == null) return null;
  return PhotoSource(
    id: newRecipeId(),
    kind: PhotoSourceKind.mediaFolder,
    name: folder.name,
    location: folder.path,
  );
}
