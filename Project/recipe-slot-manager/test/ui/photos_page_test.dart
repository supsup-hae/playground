import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_slot_manager/photo/photo_info.dart';
import 'package:recipe_slot_manager/photo/photo_source.dart';
import 'package:recipe_slot_manager/photo/place.dart';
import 'package:recipe_slot_manager/ui/photo_detail_page.dart';
import 'package:recipe_slot_manager/ui/photo_sources_panel.dart';
import 'package:recipe_slot_manager/ui/photos_page.dart';
import 'package:recipe_slot_manager/ui/recipe_editor_page.dart';

import '../support/test_app.dart';

const eterna = 0x10;
const classicNeg = 0x11;

void main() {
  late TestApp app;

  const shibuya = (latitude: 35.6587, longitude: 139.7005);
  const harajuku = (latitude: 35.6702, longitude: 139.7027);
  const namba = (latitude: 34.6662, longitude: 135.5012);

  IndexedPhoto photo(
    String name, {
    DateTime? shotAt,
    GeoPoint? location,
    int? film,
  }) => IndexedPhoto(
    sourceId: 's1',
    file: (id: name, name: name, size: 1, modifiedMs: 1),
    info: PhotoInfo(
      shotAt: shotAt,
      utcOffset: const Duration(hours: 9),
      location: location,
      model: 'X-T5',
      recipe: {'filmSimulation': ?film?.toDouble(), 'highlight': -2},
    ),
  );

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    await app.photoStore.saveSource(
      const PhotoSource(
        id: 's1',
        kind: PhotoSourceKind.folder,
        name: 'X-T5',
        location: '/photos',
      ),
    );
    await app.photoStore.replacePhotos('s1', [
      photo(
        'a.jpg',
        shotAt: DateTime.utc(2025, 10, 12, 15, 26),
        location: shibuya,
        film: eterna,
      ),
      photo(
        'b.jpg',
        shotAt: DateTime.utc(2025, 10, 12, 16),
        location: harajuku,
        film: eterna,
      ),
      photo(
        'c.jpg',
        shotAt: DateTime.utc(2025, 10, 14, 9),
        location: namba,
        film: classicNeg,
      ),
      photo('d.jpg', shotAt: DateTime.utc(2026, 3, 1), film: eterna),
      photo('e.jpg'),
    ]);
    await app.placeStore.save(
      placeKey(shibuya),
      const Place(
        country: '일본',
        admin: '도쿄도',
        locality: '시부야구',
        subLocality: '진난',
      ),
    );
    await app.placeStore.save(
      placeKey(harajuku),
      const Place(
        country: '일본',
        admin: '도쿄도',
        locality: '시부야구',
        subLocality: '진구마에',
      ),
    );
    await app.placeStore.save(
      placeKey(namba),
      const Place(country: '일본', admin: '오사카부', locality: '오사카시'),
    );
  });

  setUp(() => app = TestApp());
  tearDown(() => app.dispose());

  Future<void> pumpPhotos(
    WidgetTester tester, {
    Size size = TestApp.largeWindow,
    PhotoSource? picked,
  }) async {
    await seed(tester);
    await app.pumpPage(
      tester,
      Scaffold(
        body: PhotosPage(
          setup: app.photos(addSource: (_) async => picked),
          library: app.library,
        ),
      ),
      size: size,
    );
    await tester.pumpAndSettle();
  }

  Finder countText(String text) => find.text(text);

  testWidgets('목록은 날짜별로 최신순, 날짜 줄에 장소 이름을 보인다', (tester) async {
    await pumpPhotos(tester);

    expect(countText('5장 · 위치 없음 2장'), findsOneWidget);
    final dates = ['2026-03-01', '2025-10-14', '2025-10-12', '날짜 없음'];
    final tops = [
      for (final d in dates) tester.getTopLeft(find.textContaining(d)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(find.text('2025-10-12 · 시부야구, 일본'), findsOneWidget);
    expect(find.text('2025-10-14 · 오사카시, 일본'), findsOneWidget);
  });

  testWidgets('검색어로 거른다', (tester) async {
    await pumpPhotos(tester);

    await tester.enterText(find.byType(TextField), '시부야 eterna');
    await tester.pumpAndSettle();

    expect(countText('2장 · 위치 없음 0장'), findsOneWidget);
  });

  testWidgets('필름 시뮬레이션 칩으로 거른다', (tester) async {
    await pumpPhotos(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'Classic Neg. 1'));
    await tester.pumpAndSettle();

    expect(countText('1장 · 위치 없음 0장'), findsOneWidget);
    expect(app.photoFilter.value.films, {classicNeg});
  });

  testWidgets('연도를 고른다', (tester) async {
    await pumpPhotos(tester);

    await tester.tap(find.text('연도'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025년').last);
    await tester.pumpAndSettle();

    expect(countText('3장 · 위치 없음 0장'), findsOneWidget);
  });

  testWidgets('연도를 고른 뒤 모든 연도를 고르면 해제된다', (tester) async {
    await pumpPhotos(tester);
    await tester.tap(find.text('연도'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025년').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('2025년'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('모든 연도'));
    await tester.pumpAndSettle();

    expect(countText('5장 · 위치 없음 2장'), findsOneWidget);
    expect(app.photoFilter.value.year, isNull);
  });

  testWidgets('지역은 나라 → 광역 → 도시 차례로 고르고, 해제할 수 있다', (tester) async {
    await pumpPhotos(tester);

    await tester.tap(find.text('지역'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일본').last);
    await tester.pumpAndSettle();
    expect(countText('3장 · 위치 없음 0장'), findsOneWidget);

    await tester.tap(find.text('일본'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('도쿄도').last);
    await tester.pumpAndSettle();
    expect(countText('2장 · 위치 없음 0장'), findsOneWidget);

    await tester.tap(find.text('일본 › 도쿄도'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지역 해제'));
    await tester.pumpAndSettle();
    expect(countText('5장 · 위치 없음 2장'), findsOneWidget);
  });

  testWidgets('위치 없음 칩은 위치 없는 사진만 보인다', (tester) async {
    await pumpPhotos(tester);

    await tester.tap(find.widgetWithText(FilterChip, '위치 없음 2'));
    await tester.pumpAndSettle();

    expect(countText('2장 · 위치 없음 2장'), findsOneWidget);
  });

  testWidgets('지도에서 묶인 점을 누르면 그 사진 목록, 사진을 누르면 상세', (tester) async {
    await pumpPhotos(tester);

    await tester.tap(find.text('지도'));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsWidgets);

    final cluster = find.byKey(const ValueKey('cluster-2'));
    expect(cluster, findsOneWidget, reason: '시부야·하라주쿠 2장이 한 점');
    await tester.tap(cluster);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photo-a.jpg')).last);
    await tester.pumpAndSettle();

    expect(find.byType(PhotoDetailPage), findsOneWidget);
  });

  testWidgets('상세는 시각·장소·레시피를 보이고, 레시피로 가져오면 편집 화면이 열린다', (tester) async {
    await pumpPhotos(tester);

    await tester.tap(find.byKey(const ValueKey('photo-a.jpg')));
    await tester.pumpAndSettle();

    expect(find.text('2025-10-12 15:26 (+09:00)'), findsOneWidget);
    expect(find.text('일본 도쿄도 시부야구 진난'), findsOneWidget);
    expect(find.text('Eterna'), findsOneWidget);
    await tester.tap(find.text('레시피로 가져오기'));
    await tester.pumpAndSettle();

    expect(find.byType(RecipeEditorPage), findsOneWidget);
  });

  testWidgets('조건에 맞는 사진이 없으면 그렇다고 알린다', (tester) async {
    await pumpPhotos(tester);

    await tester.enterText(find.byType(TextField), '없는 장소');
    await tester.pumpAndSettle();

    expect(find.text('조건에 맞는 사진이 없습니다'), findsOneWidget);
  });

  testWidgets('지도에 찍을 위치가 없으면 위치 동기화를 안내한다', (tester) async {
    await pumpPhotos(tester);
    await tester.tap(find.widgetWithText(FilterChip, '위치 없음 2'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('지도'));
    await tester.pumpAndSettle();

    expect(find.textContaining('위치가 있는 사진이 없습니다'), findsOneWidget);
  });

  testWidgets('출처 버튼은 출처 관리를 시트로 연다', (tester) async {
    await pumpPhotos(tester);

    await tester.tap(find.byTooltip('사진 출처'));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoSourcesPanel), findsOneWidget);
  });

  testWidgets('출처 시트 안의 알림은 시트 위에 보인다', (tester) async {
    await pumpPhotos(
      tester,
      picked: const PhotoSource(
        id: 'dup',
        kind: PhotoSourceKind.folder,
        name: 'X-T5',
        location: '/photos',
      ),
    );
    await tester.tap(find.byTooltip('사진 출처'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('이미 추가한 출처입니다'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('찾기 조건은 화면을 다시 만들어도 남는다', (tester) async {
    await pumpPhotos(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Classic Neg. 1'));
    await tester.pumpAndSettle();

    await app.pumpPage(
      tester,
      Scaffold(
        body: PhotosPage(setup: app.photos(), library: app.library),
      ),
    );
    await tester.pumpAndSettle();

    expect(countText('1장 · 위치 없음 0장'), findsOneWidget);
  });

  for (final size in const [Size(360, 800), Size(412, 915), Size(915, 412)]) {
    testWidgets('휴대폰 크기 $size 에서 목록·지도·상세가 넘치지 않는다', (tester) async {
      await pumpPhotos(tester, size: size);
      expect(tester.takeException(), isNull, reason: '목록');

      await tester.tap(find.text('지도'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '지도');

      await tester.tap(find.text('목록'));
      await tester.pumpAndSettle();
      // 가로 화면은 검색·필터 아래 목록이 짧아 내려야 보인다.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('photo-a.jpg')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const ValueKey('photo-a.jpg')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '상세');
    });
  }
}
