# Plan: 장소 이름과 찾기 화면 (사진 기록 3·4단계)

## Summary
3단계: 사진 좌표를 기기 내장 주소 변환(macOS `CLGeocoder`, Android `Geocoder`)으로 나라·광역·도시·동네·길 이름으로 바꾸고, 반올림 좌표별로 캐시한다. 색인이 끝나면 이름이 없는 좌표만 차례로 묻는다.
4단계: "사진" 탭 위쪽에 **목록 | 지도** 전환을 두고, 기간·지역(나라 → 광역 → 도시)·필름 시뮬레이션 필터와 검색창으로 거른다. 지도는 `flutter_map` + OpenStreetMap, 점은 격자로 묶는다. 사진을 누르면 썸네일, 길 이름, 촬영 시각, 레시피 값을 보인다. 출처 관리(현재 사진 화면)는 같은 탭의 "출처" 시트로 옮긴다.

PR 은 3단계(장소 이름)와 4단계(찾기 화면) 두 개로 나눈다.

## User Story
As X-T5 사용자, I want "1년 전·일본·Eterna" 로 걸러 지도에서 골목 사진을 바로 찾기를, so that 그때 장소와 레시피를 30초 안에 다시 본다.

## Metadata
- **Complexity**: Large
- **Source PRD**: `Project/recipe-slot-manager/docs/photo-log.prd.md`
- **PRD Phase**: 3. 장소 이름, 4. 찾기 화면
- **새 의존성**: `flutter_map` 8.3.2(53일 전 게시), `latlong2`(flutter_map 의존성 범위 0.9.1–0.11). 점 묶기 패키지는 쓰지 않는다

---

## 결정 필요 (승인 때 함께 정한다)

| # | 무엇 | 제안 | 다른 선택 | 이유 |
|---|---|---|---|---|
| D1 | 검색 | 앱 안 검색: 색인(수천 건)을 메모리에서 거른다. 검색어를 띄어쓰기로 나눠 모든 낱말이 장소 이름(나라~길)·파일 이름·시뮬레이션 이름 중 하나에 들어 있으면 맞는 것으로 본다 | 전문 검색 엔진(Meilisearch·Elasticsearch), Supabase 전문 검색 | 본인 사진 수천 장은 기기 메모리에서 바로 걸러진다. 서버·색인 운영이 없다. 6단계 동기화 뒤에도 각 기기에 같은 색인이 있어 그대로 쓴다 |
| D2 | 지명 언어 | 기기 언어(한국어)로 받는다. "도쿄", "시부야구"로 찾는다 | 현지어(日本語)도 함께 저장 | 현지어까지 받으면 변환 요청이 두 배다. 필요하면 나중에 더한다 |
| D3 | 지역 필터 | 데이터에서 만든 단계 선택: 나라 → 광역 → 도시. 동네·길은 검색창과 지도로 찾는다 | 나라~길 5단계 모두 선택 | 길 이름은 수가 많아 선택 목록보다 검색이 빠르다 |
| D4 | 점 묶기 | 지도 확대 수준에 맞춘 격자로 직접 묶는다(Dart 40줄 안팎) | `flutter_map_marker_cluster` 8.2.2(13개월 전 게시) | 묶은 수만 원 안에 보이면 된다. 의존성을 하나 줄인다 |

---

## UX Design

### 사진 탭 (휴대폰)
```
┌ 사진 ───────────────── [출처 ⚙] ┐
│ [ 목록 | 지도 ]                  │
│ 🔍 시부야 Eterna                 │
│ [2025년 ▾] [일본 › 도쿄도 ▾]     │
│ [Eterna ✕] [Classic Neg.] …      │
│ 128장 · 위치 없음 12장           │
├──────────────────────────────────┤
│ 목록: 날짜순 그룹                 │
│  2025-10-12  시부야구 진난        │
│   ▢ ▢ ▢ ▢  (썸네일 격자)          │
│ 지도: OSM + 묶인 점(수)           │
│  ⓘ © OpenStreetMap contributors   │
└──────────────────────────────────┘
사진 상세: 썸네일 · 2025-10-12 15:26 (+09:00) · 일본 도쿄도 시부야구 진난 · 레시피 값 표 · "레시피로 가져오기"
```

### Interaction Changes
| Touchpoint | Before | After |
|---|---|---|
| 사진 탭 | 출처 목록·요약 | 찾기(목록/지도/필터/검색). 출처 관리는 오른쪽 위 "출처" 시트 |
| 지역 | 없음 | 색인 뒤 이름 없는 좌표를 자동 변환, 필터·검색·상세에 쓰임 |
| 위치 없음 | 요약 숫자 | 필터 줄 아래 "위치 없음 N장" 을 누르면 그 사진만 목록으로 |

---

## Mandatory Reading

| Priority | File | Why |
|---|---|---|
| P0 | `lib/photo/photo_index_store.dart`, `photo_indexer.dart`, `photo_source.dart` | 색인 모델, `indexAll` 끝에 장소 변환을 잇는다 |
| P0 | `lib/photo/folder_reader.dart`, `media_folder_reader.dart`, `macos/Runner/BookmarkChannel.swift`, `android/.../PhotoChannel.kt` | 썸네일 읽기를 더한다. 채널 등록 방식 |
| P0 | `lib/ui/photos_page.dart`, `app_shell.dart` | 사진 탭을 찾기 화면으로 바꾼다 |
| P1 | `lib/import/text_recognizer.dart`, `macos/Runner/OcrChannel.swift` | 플랫폼 채널과 백그라운드 큐 |
| P1 | `lib/ui/import_menu.dart` | EXIF 값으로 레시피 편집 화면 열기(사진 상세의 "레시피로 가져오기") |
| P2 | `test/support/test_app.dart`, `fake_photo_reader.dart` | 화면 시험 준비 |

## External Documentation

| Topic | Source | Key Takeaway |
|---|---|---|
| OSM 타일 정책 | operations.osmfoundation.org/policies/tiles | `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, 앱을 밝히는 User-Agent 필수(라이브러리 기본값은 차단), 보이는 저작권 표시, 캐시 헤더 준수(최소 7일), 미리 받기·오프라인 저장 금지 |
| flutter_map 8.3.2 | pub.dev, docs.fleaflet.dev | `TileLayer(urlTemplate, userAgentPackageName)`, `RichAttributionWidget`. 내장 타일 캐시 동작은 구현 때 문서로 확인 |
| CLGeocoder | Apple | `reverseGeocodeLocation(_:preferredLocale:)`. 앱별 호출 제한, 한 인스턴스는 한 번에 요청 하나 |
| Android Geocoder | Android | API 33+ `getFromLocation(lat, lng, 1, listener)`, 미만은 동기 메서드. `Geocoder.isPresent()` 가 false 면 쓸 수 없다. 네트워크 필요 |

---

## Files to Change

### 3단계 (PR 1)
| File | Action | Justification |
|---|---|---|
| `lib/photo/place.dart` | CREATE | `Place`(country, admin, locality, subLocality, thoroughfare), 좌표 키(소수 넷째 자리), JSON |
| `lib/photo/place_store.dart` | CREATE | `places.json` 캐시: 키 → `Place` 또는 실패 시각 |
| `lib/photo/geocoder.dart` | CREATE | 채널 `recipe_slot_manager/geocoder` 호출, `GeocodeException` |
| `lib/photo/place_resolver.dart` | CREATE | 색인의 좌표 중 이름 없는 키만 차례로 변환. 요청 사이 간격, 네트워크 오류면 멈추고 다음 색인 때 다시 |
| `lib/photo/photo_indexer.dart` | UPDATE | `indexAll` 끝에 `PlaceResolver.resolveMissing()` |
| `macos/Runner/GeocoderChannel.swift`, `MainFlutterWindow.swift`, `project.pbxproj` | CREATE/UPDATE | `CLGeocoder`, 한국어 |
| `android/.../GeocoderChannel.kt`, `MainActivity.kt` | CREATE/UPDATE | `Geocoder(context, Locale.KOREAN)` |
| `lib/main.dart` | UPDATE | 연결 |
| 시험: `place_test`, `place_store_test`, `place_resolver_test`, `geocoder_test` | CREATE | |

### 4단계 (PR 2)
| File | Action | Justification |
|---|---|---|
| `pubspec.yaml` | UPDATE | `flutter_map`, `latlong2` |
| `lib/photo/photo_query.dart` | CREATE | 필터(기간, 나라·광역·도시, 시뮬레이션 여러 개, 위치 없음만)와 검색어로 항목 거르기, 선택지(지역·연도·시뮬레이션) 만들기 |
| `lib/photo/map_clusters.dart` | CREATE | 확대 수준별 격자 묶기 |
| `lib/photo/folder_reader.dart`, `media_folder_reader.dart`, `photo_source.dart` | UPDATE | `thumbnail(source, file, width)` |
| `BookmarkChannel`·`PhotoChannel.kt` | UPDATE | Android `loadThumbnail` (macOS 는 Dart 가 파일을 읽고 `cacheWidth` 로 줄인다) |
| `lib/ui/photos_page.dart` | UPDATE | 찾기 화면(목록·지도 전환, 필터 줄, 검색창) |
| `lib/ui/photo_sources_sheet.dart` | CREATE | 지금의 출처 관리 화면을 시트로 |
| `lib/ui/photo_map_view.dart`, `photo_list_view.dart`, `photo_detail_page.dart` | CREATE | |
| 시험: `photo_query_test`, `map_clusters_test`, 화면 시험 | CREATE/UPDATE | |
| `docs/photo-log.prd.md`, `docs/unverified.md` | UPDATE | |

## NOT Building
- 현지어 지명(D2), 지명으로 지도 이동(정방향 주소 변환)
- 오프라인 지도, 타일 미리 받기(OSM 정책상 금지)
- 위치 기록(5단계), 동기화(6단계)
- 사진 원본 보기·공유·편집

---

## Step-by-Step Tasks

### 3단계
- **P1 `Place`·좌표 키**: 키 `"35.6587,139.7004"`(소수 넷째 자리, 약 10 m). JSON 왕복. 화면용 `label`(동네·도시·나라 순, 빈 칸은 건너뜀)
- **P2 `PlaceStore`**: `place(key)`, `save(key, place)`, `markFailed(key, at)`. 깨진 파일은 다른 저장소와 같이 옮기고 빈 캐시
- **P3 `Geocoder`(Dart)**: `reverse(lat, lng) → Place?`. 결과 없음은 null(바다 등), `network`·`throttled` 오류는 `GeocodeException`, 플러그인 없음도 `GeocodeException`
- **P4 `PlaceResolver.resolveMissing()`**: 색인 사진의 키 중 캐시에 없는 것만 차례로. 요청 사이 1초. `GeocodeException` 이면 멈추고 남은 수를 로그(`장소 이름: 받음 N, 남음 M`). 결과 없음은 빈 `Place` 로 저장해 다시 묻지 않는다. 진행은 색인기 진행과 같은 줄에 보인다
- **P5 Swift `GeocoderChannel`**: `reverse({lat, lng})` → `{country, admin, locality, subLocality, thoroughfare}` 또는 null. `preferredLocale: ko_KR`. 오류 코드 `network`(kCLErrorNetwork)·`throttled`
- **P6 Kotlin `GeocoderChannel`**: `Geocoder.isPresent()` 아니면 `unavailable`. API 33+ 리스너, 미만은 작업 스레드에서 동기 호출. `IOException` → `network`
- **P7 연결**: `indexAll` 이 끝나면 `resolveMissing` (자동 색인 포함)

### 4단계
- **B1 `PhotoQuery`**: `({DateTimeRange? period, String? country, String? admin, String? locality, Set<int> films, bool noLocationOnly, String text})` → 항목 목록(촬영 시각 최신순). 검색은 D1. 선택지: 데이터에 있는 연도, 나라 → 그 나라의 광역 → 도시, 시뮬레이션(수 포함)
- **B2 `clusterPoints(points, zoom)`**: 화면 픽셀 기준 격자(60 px)로 묶어 `(center, count, photos)`
- **B3 썸네일**: macOS 는 북마크 접근을 열고 파일을 읽는다(색인 때처럼 끝나면 닫음), Android 는 `ContentResolver.loadThumbnail(uri, Size(w, w))`
- **B4 찾기 화면**: 위쪽 `SegmentedButton` 목록/지도, 검색창, 필터 칩(기간·지역·시뮬레이션), 결과 수와 "위치 없음 N장". 필터 상태는 화면을 오가도 남는다(셸이 들고 있음)
- **B5 목록**: 날짜 그룹, 그룹 제목에 장소 `label`, 썸네일 격자(휴대폰 3열, 넓은 창 6열)
- **B6 지도**: `TileLayer`(OSM URL, `userAgentPackageName: dev.supsuphae.recipe_slot_manager`), 묶인 점, 누르면 그 사진 목록 시트. 저작권 표시. 필터를 바꾸면 결과에 맞춰 화면 이동
- **B7 사진 상세**: 썸네일, 촬영 시각·시간대, 장소 전체, 기종·촬영 번호, 레시피 값 표, "레시피로 가져오기"(편집 화면, 출처 "사진 세부정보 (EXIF)")
- **B8 출처 시트**: 지금 사진 화면 내용을 `photo_sources_sheet.dart` 로

---

## Testing Strategy

| Test | Expected |
|---|---|
| 좌표 키 | 반올림·음수·경계 |
| 캐시 왕복·깨진 파일 | |
| 변환: 없는 키만 요청, 1초 간격, 네트워크 오류면 멈추고 다음에 이어 감, 결과 없음 저장 | 가짜 채널·가짜 시계 |
| 색인 뒤 자동 변환 | `indexAll` 끝에 호출 |
| 필터: 기간, 나라·광역·도시, 시뮬레이션 여러 개, 위치 없음만, 조합 | |
| 검색: 낱말 AND, 장소·파일·시뮬레이션 이름, 대소문자 무시, 빈 검색어 | |
| 선택지: 연도·지역 단계·시뮬레이션 수 | |
| 격자 묶기: 확대 수준별 묶음 수, 경도 ±180 근처 | |
| 화면: 목록/지도 전환, 필터·검색 반영, 위치 없음, 상세, 레시피로 가져오기, 출처 시트, 휴대폰 3크기 넘침 없음 | 지도 타일은 시험에서 네트워크를 쓰지 않도록 타일 공급자를 주입 |
| 성공 기준 시나리오 | 가짜 색인 2,000장에서 "2025년·일본·Eterna" → 지도 → 상세 |

## Validation Commands
```bash
cd Project/recipe-slot-manager
flutter analyze
dart format --set-exit-if-changed lib test tool
flutter test
flutter build macos --debug
flutter build apk --debug
```

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| 지금 사진에 GPS 가 없다 | H | H | 위치 없음 필터·날짜·시뮬레이션은 동작. XApp 위치 동기화 확인은 미확인 항목 |
| 기기 주소 변환 호출 제한 | M | M | 좌표 캐시, 1초 간격, 오류면 멈추고 다음 색인 때 이어 감 |
| 일본 주소의 단계가 기기마다 다르게 온다(도시·동네 칸) | M | M | 화면은 빈 칸을 건너뛰고, 검색은 모든 칸을 본다. 실기기 확인 |
| OSM 타일 정책 위반 | L | H | User-Agent, 저작권 표시, 미리 받기 없음 |
| 사진 수천 장에서 지도·목록 느림 | M | M | 격자 묶기, 목록은 보이는 줄만 그림(`SliverGrid`), 썸네일 크기 제한 |

---

## 구현 중 바뀐 점 (3단계)

- 장소 캐시는 실패 시각을 저장하지 않는다. 변환이 실패하면 거기서 멈추고, 다음 `indexAll` 이 남은 좌표를 다시 묻는다
- `Geocoder` 를 인터페이스로 두고 `PlatformGeocoder` 가 채널을 쓴다. 시험은 가짜 Geocoder 로 한다
- 장소 변환 진행은 색인기 진행에 "장소 이름" 으로 보인다
- macOS·Android 모두 `network` 오류에 호출 제한도 포함된다(`throttled` 를 따로 받지 않는다)
