import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:recipe_slot_manager/camera/android_ptp_transport.dart';
import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/camera/camera_session.dart';
import 'package:recipe_slot_manager/camera/fuji_camera.dart';
import 'package:recipe_slot_manager/camera/macos_ptp_transport.dart';
import 'package:recipe_slot_manager/camera/slot_backup_store.dart';
import 'package:recipe_slot_manager/design/app_theme.dart';
import 'package:recipe_slot_manager/library/library_store.dart';
import 'package:recipe_slot_manager/photo/auto_index.dart';
import 'package:recipe_slot_manager/photo/folder_reader.dart';
import 'package:recipe_slot_manager/photo/geocoder.dart';
import 'package:recipe_slot_manager/photo/locator.dart';
import 'package:recipe_slot_manager/photo/media_folder_reader.dart';
import 'package:recipe_slot_manager/photo/photo_index_store.dart';
import 'package:recipe_slot_manager/photo/photo_indexer.dart';
import 'package:recipe_slot_manager/photo/photo_query.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/photo/place_log_store.dart';
import 'package:recipe_slot_manager/photo/place_logger.dart';
import 'package:recipe_slot_manager/photo/place_resolver.dart';
import 'package:recipe_slot_manager/photo/place_store.dart';
import 'package:recipe_slot_manager/sync/remote_library.dart';
import 'package:recipe_slot_manager/sync/supabase_config.dart';
import 'package:recipe_slot_manager/sync/sync_service.dart';
import 'package:recipe_slot_manager/ui/app_shell.dart';
import 'package:recipe_slot_manager/ui/photo_source_picker.dart';
import 'package:recipe_slot_manager/ui/photo_thumbnail.dart';
import 'package:recipe_slot_manager/ui/photos_setup.dart';
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
  final (photos, placeLogger) = await _openPhotos(support, session.log);
  final (sync, auth) = await _startSync(support, library, session.log);

  runApp(
    MaterialApp(
      title: 'Recipe Slot Manager',
      theme: buildAppTheme(),
      home: AppShell(
        session: session,
        library: library,
        photos: photos,
        placeLogger: placeLogger,
        headerActions: [SyncBar(sync: sync, auth: auth)],
      ),
    ),
  );
}

/// 사진 색인·장소·세트 저장 기록을 불러오고 자동 색인을 시작한다.
Future<(PhotosSetup, PlaceLogger)> _openPhotos(
  Directory support,
  CameraLog log,
) async {
  final directory = Directory(p.join(support.path, 'photos'));
  final photoStore = PhotoIndexStore(directory);
  await photoStore.load();
  photoStore.loadErrors.forEach(log.add);
  final placeStore = PlaceStore(directory);
  await placeStore.load();
  placeStore.loadErrors.forEach(log.add);
  final placeLogs = PlaceLogStore(directory);
  await placeLogs.load();
  placeLogs.loadErrors.forEach(log.add);

  final phoneFolders = MediaFolderReader();
  final places = PlaceResolver(
    photos: photoStore,
    places: placeStore,
    geocoder: const PlatformGeocoder(),
    log: log,
    logs: placeLogs,
  );
  final indexer = PhotoIndexer(
    photoStore,
    readers: {
      PhotoSourceKind.folder: FolderReader(
        useBookmarks: Platform.isMacOS,
        onSourceRenewed: photoStore.saveSource,
      ),
      PhotoSourceKind.mediaFolder: phoneFolders,
    },
    log: log,
    places: places,
  );
  // 앱이 끝날 때까지 둔다.
  startAutoIndex(indexer);

  final PhotosSetup setup = (
    store: photoStore,
    indexer: indexer,
    places: placeStore,
    logs: placeLogs,
    thumbnails: PhotoThumbnails(indexer),
    filter: ValueNotifier(const PhotoFilter()),
    mapTiles: true,
    addSource: (context) => Platform.isAndroid
        ? pickMediaFolderSource(phoneFolders)
        : pickFolderSource(useBookmarks: Platform.isMacOS),
    allowLocation: Platform.isAndroid
        ? () async => phoneFolders.requestAccess()
        : null,
  );
  // macOS 는 위치를 받지 않고 기록만 남긴다.
  final logger = PlaceLogger(
    store: placeLogs,
    locator: Platform.isAndroid ? const PlatformLocator() : null,
    log: log,
    resolver: places,
  );
  return (setup, logger);
}

/// Supabase 설정이 있으면 연결하고, 로그인돼 있으면 동기화를 시작한다. 설정이 없으면 둘 다 null.
Future<(SyncService?, GoTrueClient?)> _startSync(
  Directory support,
  LibraryStore library,
  CameraLog log,
) async {
  if (!SupabaseConfig.isConfigured) return (null, null);
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  final client = Supabase.instance.client;
  final sync = SyncService(
    library: library,
    remote: SupabaseRemoteLibrary(client),
    log: log,
    stateFile: File(p.join(support.path, 'sync.json')),
  );
  await sync.loadState();
  if (client.auth.currentSession != null) unawaited(sync.sync());
  return (sync, client.auth);
}
