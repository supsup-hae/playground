import 'package:flutter/widgets.dart';
import 'package:recipe_slot_manager/photo/photo_index_store.dart';
import 'package:recipe_slot_manager/photo/photo_indexer.dart';
import 'package:recipe_slot_manager/photo/photo_query.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/photo/place_store.dart';
import 'package:recipe_slot_manager/ui/photo_thumbnail.dart';

/// 사진 탭에 필요한 것. 셸이 들고 있어 탭을 오가도 남는다.
///
/// - [addSource]: 플랫폼마다 다르다(macOS 폴더 고르기, Android 시스템 폴더 선택 창)
/// - [allowLocation]: Android 에서 사진 위치 권한을 다시 요청한다
/// - [filter]: 찾기 조건
/// - [mapTiles]: 지도 타일(OpenStreetMap)을 받는다. 시험에서는 끈다
typedef PhotosSetup = ({
  PhotoIndexStore store,
  PhotoIndexer indexer,
  PlaceStore places,
  PhotoThumbnails thumbnails,
  ValueNotifier<PhotoFilter> filter,
  Future<PhotoSource?> Function(BuildContext context) addSource,
  Future<void> Function()? allowLocation,
  bool mapTiles,
});
