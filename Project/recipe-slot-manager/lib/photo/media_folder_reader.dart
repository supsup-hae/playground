import 'package:flutter/services.dart';
import 'package:recipe_slot_manager/import/jpeg_exif.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';

/// Android 사진 채널. `android/.../PhotoChannel.kt` 가 받는다.
const photoChannel = MethodChannel('recipe_slot_manager/photos');

/// 권한 상태. [location] 이 없으면 기기가 위치를 지운 사본을 준다.
typedef PhotoAccess = ({bool images, bool location});

/// 폴더 선택 창에서 고른 폴더. [path] 는 `Pictures/FUJIFILM XApp/` 같은 내부 저장소 상대 경로.
typedef PickedMediaFolder = ({String path, String name});

/// Android 휴대폰 폴더 출처를 읽는다. 폴더는 시스템 폴더 선택 창으로 고르고, 사진은 그 경로와
/// 하위 폴더의 JPEG 를 MediaStore 로 찾아 읽는다. MediaStore 로 열어야 위치 권한이 있을 때
/// 위치가 든 원본을 받을 수 있다.
class MediaFolderReader implements PhotoSourceReader {
  /// 사진 읽기·사진 위치 권한을 요청한다. 이미 있으면 묻지 않는다.
  Future<PhotoAccess> requestAccess() async {
    final result = await _call<Map<Object?, Object?>>('requestAccess');
    return (
      images: result['images'] == true,
      location: result['location'] == true,
    );
  }

  /// 시스템 폴더 선택 창을 연다. 닫으면 null.
  Future<PickedMediaFolder?> pickFolder() async {
    try {
      final result = await _call<Map<Object?, Object?>>('pickFolder');
      if (result case {'path': final String path, 'name': final String name}) {
        return (path: path, name: name);
      }
      return null;
    } on PlatformException catch (e) {
      if (e.code == 'volume') {
        throw const PhotoSourceException('휴대폰 내부 저장소의 폴더만 고를 수 있습니다');
      }
      rethrow;
    }
  }

  @override
  Future<List<PhotoFile>> list(PhotoSource source) async => [
    for (final row in await _call<List<Object?>>('photos', source.location))
      if (row case {
        'id': final String id,
        'name': final String name,
        'size': final int size,
        'modified': final int modified,
      })
        (id: id, name: name, size: size, modifiedMs: modified),
  ];

  /// MediaStore 는 열어 둔 접근이 없다.
  @override
  Future<void> close(PhotoSource source) async {}

  @override
  Future<PhotoHead> readHead(
    PhotoSource source,
    PhotoFile file, {
    int length = jpegHeadBytes,
  }) async {
    final result = await _call<Map<Object?, Object?>>('readHead', {
      'id': file.id,
      'length': length,
    });
    return (
      bytes: result['bytes'] as Uint8List? ?? Uint8List(0),
      locationRedacted: result['locationRedacted'] == true,
    );
  }
}

/// 채널을 부른다. `volume` 오류는 [MediaFolderReader.pickFolder] 가 바꾸도록 그대로 던진다.
Future<T> _call<T>(String method, [Object? arguments]) async {
  try {
    final result = await photoChannel.invokeMethod<T>(method, arguments);
    if (result == null) throw PhotoSourceException('사진을 읽지 못했습니다: $method');
    return result;
  } on PlatformException catch (e) {
    if (e.code == 'volume') rethrow;
    if (e.code == 'permission') {
      throw const PhotoSourceException('사진 접근이 허용되지 않았습니다');
    }
    throw PhotoSourceException('사진을 읽지 못했습니다: ${e.message ?? e.code}');
  } on MissingPluginException {
    throw const PhotoSourceException('이 기기에서는 휴대폰 폴더를 읽을 수 없습니다');
  }
}
