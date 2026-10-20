import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:recipe_slot_manager/camera/android_ptp_transport.dart';
import 'package:recipe_slot_manager/camera/camera_session.dart';
import 'package:recipe_slot_manager/camera/fuji_camera.dart';
import 'package:recipe_slot_manager/camera/macos_ptp_transport.dart';
import 'package:recipe_slot_manager/camera/slot_backup_store.dart';
import 'package:recipe_slot_manager/design/app_theme.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/photo/album_reader.dart';
import 'package:recipe_slot_manager/photo/auto_index.dart';
import 'package:recipe_slot_manager/photo/folder_reader.dart';
import 'package:recipe_slot_manager/photo/photo_index_store.dart';
import 'package:recipe_slot_manager/photo/photo_indexer.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/sync/remote_library.dart';
import 'package:recipe_slot_manager/sync/supabase_config.dart';
import 'package:recipe_slot_manager/sync/sync_service.dart';
import 'package:recipe_slot_manager/ui/app_shell.dart';
import 'package:recipe_slot_manager/ui/photo_source_picker.dart';
import 'package:recipe_slot_manager/ui/sync_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  final session = CameraSession(
    FujiCamera(
      Platform.isAndroid ? AndroidPtpTransport() : MacosPtpTransport(),
    ),
    SlotBackupStore(Directory(p.join(support.path, 'backups'))),
  );
  final library = LibraryStore(Directory(p.join(support.path, 'library')));
  await library.load();
  library.loadErrors.forEach(session.log.add);
  final photoStore = PhotoIndexStore(Directory(p.join(support.path, 'photos')));
  await photoStore.load();
  photoStore.loadErrors.forEach(session.log.add);
  final albums = AlbumReader();
  final folders = FolderReader(
    useBookmarks: Platform.isMacOS,
    onSourceRenewed: photoStore.saveSource,
  );
  final photoIndexer = PhotoIndexer(
    photoStore,
    readers: {PhotoSourceKind.folder: folders, PhotoSourceKind.album: albums},
    log: session.log,
  );
  // 앱이 끝날 때까지 둔다.
  startAutoIndex(photoIndexer);

  SyncService? sync;
  GoTrueClient? auth;
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    final client = Supabase.instance.client;
    auth = client.auth;
    sync = SyncService(
      library: library,
      remote: SupabaseRemoteLibrary(client),
      log: session.log,
      stateFile: File(p.join(support.path, 'sync.json')),
    );
    await sync.loadState();
    if (auth.currentSession != null) unawaited(sync.sync());
  }

  runApp(
    MaterialApp(
      title: 'Recipe Slot Manager',
      theme: buildAppTheme(),
      home: AppShell(
        session: session,
        library: library,
        photos: (
          store: photoStore,
          indexer: photoIndexer,
          addSource: (context) => Platform.isAndroid
              ? pickAlbumSource(context, albums)
              : pickFolderSource(useBookmarks: Platform.isMacOS),
          allowLocation: Platform.isAndroid
              ? () async => albums.requestAccess()
              : null,
        ),
        headerActions: [SyncBar(sync: sync, auth: auth)],
      ),
    ),
  );
}
