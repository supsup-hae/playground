import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/camera/camera_session.dart';
import 'package:recipe_slot_manager/camera/fuji_camera.dart';
import 'package:recipe_slot_manager/camera/slot_backup_store.dart';
import 'package:recipe_slot_manager/design/app_theme.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/photo/photo_index_store.dart';
import 'package:recipe_slot_manager/photo/photo_indexer.dart';
import 'package:recipe_slot_manager/photo/photo_query.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/photo/place_log_store.dart';
import 'package:recipe_slot_manager/photo/place_logger.dart';
import 'package:recipe_slot_manager/photo/place_store.dart';
import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/ptp/ptp_string.dart';
import 'package:recipe_slot_manager/ui/app_shell.dart';
import 'package:recipe_slot_manager/ui/photo_thumbnail.dart';
import 'package:recipe_slot_manager/ui/photos_setup.dart';

import 'fake_locator.dart';
import 'fake_photo_reader.dart';
import 'fake_ptp_transport.dart';

Uint8List u16(int value) => (ByteData(
  2,
)..setUint16(0, value & 0xFFFF, Endian.little)).buffer.asUint8List();

/// 화면 시험 준비: 가짜 카메라(슬롯 n 의 모든 속성 값 n, 이름 `Recipe n`), 임시 폴더의
/// 백업·보관함, 카메라 세션.
class TestApp {
  TestApp()
    : root = Directory.systemTemp.createTempSync('recipe_slot_manager_test'),
      transport = FakePtpTransport(
        slots: {
          for (var slot = 1; slot <= FujiProp.slotCount; slot++)
            slot: {
              FujiProp.presetName: encodePtpString('Recipe $slot'),
              for (final code in FujiProp.presetProps) code: u16(slot),
            },
        },
      ) {
    backups = SlotBackupStore(Directory(p.join(root.path, 'backups')));
    library = LibraryStore(Directory(p.join(root.path, 'library')));
    session = CameraSession(
      FujiCamera(transport, slotSwitchDelay: Duration.zero),
      backups,
    );
    photoStore = PhotoIndexStore(Directory(p.join(root.path, 'photos')));
    // 시험 본문(가짜 시간) 밖에서 만들어야 runAsync 안에서 쓰기를 기다릴 수 있다.
    placeLogStore = PlaceLogStore(Directory(p.join(root.path, 'photos')));
    placeStore = PlaceStore(Directory(p.join(root.path, 'photos')));
  }

  final Directory root;
  final FakePtpTransport transport;
  late final SlotBackupStore backups;
  late final LibraryStore library;
  late final CameraSession session;
  late final PhotoIndexStore photoStore;

  /// 모든 출처(폴더)를 읽는 가짜 출처.
  final photoReader = FakePhotoReader();

  late final PlaceStore placeStore;

  late final PlaceLogStore placeLogStore;

  /// 위치를 받지 못하는 가짜 위치. 시험에서 [FakeLocator.fix] 를 넣는다.
  final locator = FakeLocator();

  late final placeLogger = PlaceLogger(
    store: placeLogStore,
    locator: locator,
    log: session.log,
  );

  /// 찾기 조건. 셸처럼 시험 하나 동안 같은 것을 쓴다.
  final photoFilter = ValueNotifier(const PhotoFilter());

  late final photoIndexer = PhotoIndexer(
    photoStore,
    readers: {
      PhotoSourceKind.folder: photoReader,
      PhotoSourceKind.mediaFolder: photoReader,
    },
    log: session.log,
  );

  /// 사진 화면 준비. [addSource] 가 없으면 출처를 고르지 않은 것으로 본다. 지도 타일은 받지 않는다.
  PhotosSetup photos({
    Future<PhotoSource?> Function(BuildContext context)? addSource,
    Future<void> Function()? allowLocation,
  }) => (
    store: photoStore,
    indexer: photoIndexer,
    places: placeStore,
    logs: placeLogStore,
    thumbnails: PhotoThumbnails(photoIndexer),
    filter: photoFilter,
    addSource: addSource ?? (_) async => null,
    allowLocation: allowLocation,
    mapTiles: false,
  );

  void dispose() => root.deleteSync(recursive: true);

  static const largeWindow = Size(1800, 1400);

  /// 화면 크기를 논리 픽셀로 정한다.
  static void useWindow(WidgetTester tester, [Size size = largeWindow]) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpShell(
    WidgetTester tester, {
    int index = 0,
    Size size = largeWindow,
    List<Widget> headerActions = const [],
  }) async {
    useWindow(tester, size);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AppShell(
          session: session,
          library: library,
          photos: photos(),
          placeLogger: placeLogger,
          initialIndex: index,
          headerActions: headerActions,
        ),
      ),
    );
  }

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    Size size = largeWindow,
  }) async {
    useWindow(tester, size);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: page));
  }

  /// 가짜 카메라 응답과 실제 파일 입출력이 끝날 때까지 기다린다.
  static Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  static Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settle(tester);
  }
}
