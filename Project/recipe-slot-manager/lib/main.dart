import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:recipe_slot_manager/camera/fuji_camera.dart';
import 'package:recipe_slot_manager/camera/macos_ptp_transport.dart';
import 'package:recipe_slot_manager/camera/slot_backup_store.dart';
import 'package:recipe_slot_manager/design/app_theme.dart';
import 'package:recipe_slot_manager/ui/slots_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  final backupStore = SlotBackupStore(
    Directory(p.join(support.path, 'backups')),
  );
  final camera = FujiCamera(MacosPtpTransport());

  runApp(
    MaterialApp(
      title: 'Recipe Slot Manager',
      theme: buildAppTheme(),
      home: SlotsPage(camera: camera, backupStore: backupStore),
    ),
  );
}
