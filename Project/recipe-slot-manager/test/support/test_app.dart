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
import 'package:recipe_slot_manager/ptp/ptp_codes.dart';
import 'package:recipe_slot_manager/ptp/ptp_string.dart';
import 'package:recipe_slot_manager/ui/app_shell.dart';

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
  }

  final Directory root;
  final FakePtpTransport transport;
  late final SlotBackupStore backups;
  late final LibraryStore library;
  late final CameraSession session;

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
