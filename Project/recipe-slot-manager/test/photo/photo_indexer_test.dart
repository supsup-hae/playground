import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/camera/camera_log.dart';
import 'package:recipe_slot_manager/photo/photo_index_store.dart';
import 'package:recipe_slot_manager/photo/photo_indexer.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/photo/place_resolver.dart';
import 'package:recipe_slot_manager/photo/place_store.dart';

import '../support/fake_geocoder.dart';
import '../support/fake_photo_reader.dart';

void main() {
  late Directory root;
  late PhotoIndexStore store;
  late FakePhotoReader reader;
  late CameraLog log;
  late PhotoIndexer indexer;

  const source = PhotoSource(
    id: 's1',
    kind: PhotoSourceKind.folder,
    name: 'X-T5',
    location: '/photos',
  );

  setUp(() async {
    root = Directory.systemTemp.createTempSync('photo_indexer_test');
    store = PhotoIndexStore(root);
    reader = FakePhotoReader();
    log = CameraLog();
    indexer = PhotoIndexer(
      store,
      readers: {PhotoSourceKind.folder: reader},
      log: log,
    );
    await store.saveSource(source);
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('처음 색인하면 모든 사진을 읽어 저장한다', () async {
    reader
      ..put('a.jpg', bytes: fujiJpeg(filmMode: 0x700))
      ..put('b.jpg', bytes: fujiJpeg(filmMode: 0x800))
      ..put('c.jpg');

    final result = await indexer.index(source);

    expect(result.added, 3);
    expect(reader.reads, hasLength(3));
    expect(store.photosOf('s1'), hasLength(3));
    expect(store.summary.byFilmSimulation, {0x10: 2, 0x11: 1});
    expect(store.sourceById('s1')!.indexedAt, isNotNull);
    expect(log.entries.last.$2, startsWith('사진 색인: 새로 3, 바뀜 0, 지움 0, 실패 0'));
  });

  test('바뀐 것이 없으면 사진을 다시 읽지 않는다', () async {
    reader
      ..put('a.jpg')
      ..put('b.jpg');
    await indexer.index(source);
    reader.reads.clear();

    final result = await indexer.index(source);

    expect(reader.reads, isEmpty);
    expect((result.added, result.changed, result.removed), (0, 0, 0));
    expect(store.photosOf('s1'), hasLength(2));
  });

  test('크기나 수정 시각이 바뀐 사진만 다시 읽는다', () async {
    reader
      ..put('a.jpg')
      ..put('b.jpg');
    await indexer.index(source);
    reader
      ..reads.clear()
      ..put('a.jpg', size: 200)
      ..put('b.jpg', modifiedMs: 1)
      ..put('c.jpg', modifiedMs: 5);

    final result = await indexer.index(source);

    expect(reader.reads, unorderedEquals(['a.jpg', 'c.jpg']));
    expect((result.added, result.changed), (1, 1));
  });

  test('목록에서 사라진 사진은 색인에서 지운다', () async {
    reader
      ..put('a.jpg')
      ..put('b.jpg');
    await indexer.index(source);
    reader.files.remove('b.jpg');

    final result = await indexer.index(source);

    expect(result.removed, 1);
    expect(store.photosOf('s1').map((p) => p.file.id), ['a.jpg']);
  });

  test('읽지 못한 사진은 오류로 남기고, 바뀌기 전에는 다시 읽지 않는다', () async {
    reader.put('broken.jpg', bytes: Uint8List.fromList([1, 2, 3]));

    final first = await indexer.index(source);
    reader.reads.clear();
    await indexer.index(source);

    expect(first.failed, 1);
    expect(store.photosOf('s1').single.error, 'JPEG 파일이 아닙니다');
    expect(reader.reads, isEmpty);
  });

  test('위치가 가려진 채 읽은 사진은 다음 색인에서 다시 읽는다', () async {
    reader.put('a.jpg', redacted: true);
    await indexer.index(source);
    expect(store.photosOf('s1').single.locationRedacted, isTrue);
    reader
      ..reads.clear()
      ..put('a.jpg');

    await indexer.index(source);

    expect(reader.reads, ['a.jpg']);
    expect(store.photosOf('s1').single.locationRedacted, isFalse);
  });

  test('출처 목록을 읽지 못하면 색인을 바꾸지 않고 예외를 전한다', () async {
    reader.put('a.jpg');
    await indexer.index(source);
    reader.listError = const PhotoSourceException('폴더를 찾을 수 없습니다');

    await expectLater(
      indexer.index(source),
      throwsA(isA<PhotoSourceException>()),
    );
    expect(store.photosOf('s1'), hasLength(1));
  });

  test('읽을 사진 수 기준으로 진행을 알린다', () async {
    for (var i = 0; i < 5; i++) {
      reader.put('$i.jpg');
    }
    final progress = <(int, int)>[];

    await indexer.index(
      source,
      onProgress: (done, total) => progress.add((done, total)),
    );

    expect(progress, [(0, 5), (1, 5), (2, 5), (3, 5), (4, 5), (5, 5)]);
  });

  test('색인이 겹치면 차례로 하고, 뒤의 색인은 앞의 결과 위에서 바뀐 것만 읽는다', () async {
    reader
      ..put('a.jpg')
      ..put('b.jpg');

    final results = await Future.wait([
      indexer.index(source),
      indexer.index(source),
    ]);

    expect(results.map((r) => r.added), [2, 0]);
    expect(reader.reads, hasLength(2));
    expect(store.photosOf('s1'), hasLength(2));
  });

  test('색인이 끝나면 성공·실패와 관계없이 출처 읽기를 닫는다', () async {
    reader.put('a.jpg');
    await indexer.index(source);
    reader.listError = const PhotoSourceException('폴더를 찾을 수 없습니다: X-T5');
    await expectLater(
      indexer.index(source),
      throwsA(isA<PhotoSourceException>()),
    );

    expect(reader.closed, ['s1', 's1']);
  });

  group('indexAll', () {
    const album = PhotoSource(
      id: 's2',
      kind: PhotoSourceKind.mediaFolder,
      name: 'XApp',
      location: 'Pictures/FUJIFILM XApp/',
    );

    test('모든 출처를 차례로 읽고 진행을 알린 뒤 끝나면 진행을 비운다', () async {
      final albumReader = FakePhotoReader()..put('x.jpg');
      indexer = PhotoIndexer(
        store,
        readers: {
          PhotoSourceKind.folder: reader,
          PhotoSourceKind.mediaFolder: albumReader,
        },
        log: log,
      );
      await store.saveSource(album);
      reader.put('a.jpg');
      final seen = <String>[];
      indexer.addListener(() {
        if (indexer.progress case final p?) seen.add(p.name);
      });

      final failures = await indexer.indexAll();

      expect(failures, isEmpty);
      expect(seen.toSet(), {'X-T5', 'XApp'});
      expect(indexer.progress, isNull);
      expect(store.photos, hasLength(2));
    });

    test('읽지 못한 출처는 로그와 결과에 남기고 다음 출처를 읽는다', () async {
      indexer = PhotoIndexer(
        store,
        readers: {
          PhotoSourceKind.folder: reader,
          PhotoSourceKind.mediaFolder: FakePhotoReader()..put('x.jpg'),
        },
        log: log,
      );
      await store.saveSource(album);
      reader.listError = const PhotoSourceException('폴더를 찾을 수 없습니다: X-T5');

      final failures = await indexer.indexAll();

      expect(failures, ['폴더를 찾을 수 없습니다: X-T5']);
      expect(store.photosOf('s2'), hasLength(1));
      expect(
        log.entries.map((e) => e.$2),
        contains('사진 색인 실패: 폴더를 찾을 수 없습니다: X-T5'),
      );
    });

    test('저장소·파일 오류도 로그와 결과에 남기고 다음 출처를 읽는다', () async {
      indexer = PhotoIndexer(
        store,
        readers: {
          PhotoSourceKind.folder: reader,
          PhotoSourceKind.mediaFolder: FakePhotoReader()..put('x.jpg'),
        },
        log: log,
      );
      await store.saveSource(album);
      reader.listError = const FileSystemException('No space left on device');

      final failures = await indexer.indexAll();

      expect(failures.single, contains('No space left on device'));
      expect(store.photosOf('s2'), hasLength(1));
      expect(indexer.progress, isNull);
    });

    test('모든 출처를 읽은 뒤 장소 이름이 없는 좌표를 묻고 진행을 알린다', () async {
      final places = PlaceStore(Directory('${root.path}/places'));
      final geocoder = FakeGeocoder();
      indexer = PhotoIndexer(
        store,
        readers: {PhotoSourceKind.folder: reader},
        log: log,
        places: PlaceResolver(
          photos: store,
          places: places,
          geocoder: geocoder,
          log: log,
          wait: (_) async {},
        ),
      );
      reader.put('a.jpg', bytes: fujiJpeg(gps: (35.0, 139.0)));
      final names = <String>[];
      indexer.addListener(() {
        if (indexer.progress case final p?) names.add(p.name);
      });

      await indexer.indexAll();

      expect(geocoder.requests, hasLength(1));
      expect(places.place('35.0000,139.0000')?.country, '나라 35.0');
      expect(names.toSet(), {'X-T5', '장소 이름'});
      expect(indexer.progress, isNull);
    });

    test('이미 읽는 중이면 새로 시작하지 않는다', () async {
      reader.put('a.jpg');

      final first = indexer.indexAll();
      final second = await indexer.indexAll();
      await first;

      expect(second, isEmpty);
      expect(reader.reads, ['a.jpg']);
    });
  });

  test('100장을 10초 안에 색인한다 (가짜 출처 기준)', () async {
    for (var i = 0; i < 100; i++) {
      reader.put('$i.jpg', bytes: fujiJpeg(imageCount: i));
    }

    final result = await indexer.index(source);

    expect(result.added, 100);
    expect(result.elapsed, lessThan(const Duration(seconds: 10)));
  });
}
