import 'package:flutter/services.dart';
import 'package:recipe_slot_manager/import/jpeg_exif.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';

/// Android 사진 채널. `android/.../PhotoChannel.kt` 가 MediaStore 로 받는다.
const photoChannel = MethodChannel('recipe_slot_manager/photos');

/// 권한 상태. [location] 이 없으면 기기가 위치를 지운 사본을 준다.
typedef PhotoAccess = ({bool images, bool location});

/// MediaStore 버킷 하나.
typedef PhotoAlbum = ({String id, String name, int count});

/// Android 사진 앨범 출처를 읽는다. 출처의 [PhotoSource.location] 이 버킷 id 다.
class AlbumReader implements PhotoSourceReader {
  /// 사진 읽기·사진 위치 권한을 요청한다. 이미 있으면 묻지 않는다.
  Future<PhotoAccess> requestAccess() async {
    final result = await _call<Map<Object?, Object?>>('requestAccess');
    return (
      images: result['images'] == true,
      location: result['location'] == true,
    );
  }

  /// JPEG 가 있는 앨범.
  Future<List<PhotoAlbum>> albums() async => [
    for (final row in await _call<List<Object?>>('albums'))
      if (row case {
        'id': final String id,
        'name': final String name,
        'count': final int count,
      })
        (id: id, name: name, count: count),
  ];

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

  @override
  Future<PhotoHead> readHead(PhotoSource source, PhotoFile file) async {
    final result = await _call<Map<Object?, Object?>>('readHead', {
      'id': file.id,
      'length': jpegHeadBytes,
    });
    return (
      bytes: result['bytes'] as Uint8List? ?? Uint8List(0),
      locationRedacted: result['locationRedacted'] == true,
    );
  }
}

Future<T> _call<T>(String method, [Object? arguments]) async {
  try {
    final result = await photoChannel.invokeMethod<T>(method, arguments);
    if (result == null) throw PhotoSourceException('사진을 읽지 못했습니다: $method');
    return result;
  } on PlatformException catch (e) {
    if (e.code == 'permission') {
      throw const PhotoSourceException('사진 접근이 허용되지 않았습니다');
    }
    throw PhotoSourceException('사진을 읽지 못했습니다: ${e.message ?? e.code}');
  } on MissingPluginException {
    throw const PhotoSourceException('이 기기에서는 사진 앨범을 읽을 수 없습니다');
  }
}
