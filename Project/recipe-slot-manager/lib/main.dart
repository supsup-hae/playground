import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:recipe_slot_manager/camera/camera_session.dart';
import 'package:recipe_slot_manager/camera/fuji_camera.dart';
import 'package:recipe_slot_manager/camera/macos_ptp_transport.dart';
import 'package:recipe_slot_manager/camera/slot_backup_store.dart';
import 'package:recipe_slot_manager/design/app_theme.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  final session = CameraSession(
    FujiCamera(MacosPtpTransport()),
    SlotBackupStore(Directory(p.join(support.path, 'backups'))),
  );
  final library = LibraryStore(Directory(p.join(support.path, 'library')));
  try {
    await library.load();
  } on FormatException catch (e) {
    session.log.add('보관함을 읽지 못했다: ${e.message}');
  }

  runApp(
    MaterialApp(
      title: 'Recipe Slot Manager',
      theme: buildAppTheme(),
      home: AppShell(session: session, library: library),
    ),
  );
}
