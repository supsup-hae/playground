import 'dart:typed_data';

import 'package:recipe_slot_manager/photo/photo_info.dart';

/// 사진 출처 종류: Mac 의 폴더, Android 의 사진 앨범(MediaStore 버킷).
enum PhotoSourceKind { folder, album }

/// 색인할 사진이 있는 곳.
final class PhotoSource {
  const PhotoSource({
    required this.id,
    required this.kind,
    required this.name,
    required this.location,
    this.bookmark,
    this.indexedAt,
  });

  factory PhotoSource.fromJson(Object? json) {
    if (json case {
      'id': final String id,
      'kind': final String kind,
      'name': final String name,
      'location': final String location,
    }) {
      return PhotoSource(
        id: id,
        kind: PhotoSourceKind.values.firstWhere(
          (k) => k.name == kind,
          orElse: () => throw FormatException('사진 출처 형식 오류', kind),
        ),
        name: name,
        location: location,
        bookmark: _optionalString(json['bookmark'], '사진 출처 형식 오류'),
        indexedAt: switch (json['indexedAt']) {
          null => null,
          final String text => DateTime.parse(text).toUtc(),
          final other => throw FormatException('사진 출처 형식 오류', other),
        },
      );
    }
    throw FormatException('사진 출처 형식 오류', json);
  }

  final String id;
  final PhotoSourceKind kind;

  /// 화면에 보일 이름 (폴더 이름, 앨범 이름).
  final String name;

  /// 폴더 경로, 또는 앨범의 MediaStore 버킷 id.
  final String location;

  /// macOS 보안 범위 북마크(base64). 다음 실행에서도 폴더를 읽는 데 쓴다.
  final String? bookmark;

  /// 마지막으로 색인을 마친 시각.
  final DateTime? indexedAt;

  PhotoSource copyWith({
    String? location,
    String? bookmark,
    DateTime? indexedAt,
  }) => PhotoSource(
    id: id,
    kind: kind,
    name: name,
    location: location ?? this.location,
    bookmark: bookmark ?? this.bookmark,
    indexedAt: indexedAt ?? this.indexedAt,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'kind': kind.name,
    'name': name,
    'location': location,
    'bookmark': ?bookmark,
    if (indexedAt case final at?) 'indexedAt': at.toUtc().toIso8601String(),
  };
}

/// 출처 안의 사진 파일. [id] 는 폴더면 출처 안 상대 경로, 앨범이면 `content://` URI.
typedef PhotoFile = ({String id, String name, int size, int modifiedMs});

/// 사진 앞부분. [locationRedacted] 면 기기가 위치를 지운 사본을 준 것이다(Android 위치 권한 없음).
typedef PhotoHead = ({Uint8List bytes, bool locationRedacted});

/// 색인 항목 하나. 읽지 못한 사진은 [info] 대신 [error] 를 남긴다.
final class IndexedPhoto {
  const IndexedPhoto({
    required this.sourceId,
    required this.file,
    this.info,
    this.error,
    this.locationRedacted = false,
  });

  factory IndexedPhoto.fromJson(Object? json) {
    if (json case {
      'sourceId': final String sourceId,
      'id': final String id,
      'name': final String name,
      'size': final int size,
      'modifiedMs': final int modifiedMs,
    }) {
      return IndexedPhoto(
        sourceId: sourceId,
        file: (id: id, name: name, size: size, modifiedMs: modifiedMs),
        info: switch (json['info']) {
          null => null,
          final info => PhotoInfo.fromJson(info),
        },
        error: _optionalString(json['error'], '사진 색인 형식 오류'),
        locationRedacted: json['locationRedacted'] == true,
      );
    }
    throw FormatException('사진 색인 형식 오류', json);
  }

  final String sourceId;
  final PhotoFile file;
  final PhotoInfo? info;
  final String? error;
  final bool locationRedacted;

  Map<String, Object> toJson() => {
    'sourceId': sourceId,
    'id': file.id,
    'name': file.name,
    'size': file.size,
    'modifiedMs': file.modifiedMs,
    if (info case final info?) 'info': info.toJson(),
    'error': ?error,
    if (locationRedacted) 'locationRedacted': true,
  };
}

String? _optionalString(Object? value, String message) => switch (value) {
  null => null,
  final String text => text,
  _ => throw FormatException(message, value),
};

/// 출처를 읽지 못함(폴더 없음, 권한 없음 등). 화면은 [message] 를 그대로 보인다.
final class PhotoSourceException implements Exception {
  const PhotoSourceException(this.message);

  final String message;

  @override
  String toString() => 'PhotoSourceException: $message';
}

/// 출처의 사진 목록과 사진 앞부분을 읽는다. 폴더(macOS)와 앨범(Android)이 따로 구현한다.
abstract interface class PhotoSourceReader {
  Future<List<PhotoFile>> list(PhotoSource source);

  Future<PhotoHead> readHead(PhotoSource source, PhotoFile file);
}
