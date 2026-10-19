# Plan: 사진 색인 (사진 기록 2단계)

## Summary
Mac 폴더와 Android 앨범을 사진 출처로 등록하고, 출처의 JPEG 를 앞부분(256 KiB)만 읽어 1단계 `readPhotoInfo` 결과를 기기 JSON 에 색인한다. 다시 색인할 때는 새 사진과 바뀐 사진만 읽고, 사라진 사진은 색인에서 지운다. 셸에 "사진" 화면을 더해 출처 등록·색인 실행·진행·요약(전체, 위치 있음, 시뮬레이션별 수)을 보인다. 필터·지도는 4단계다.

## User Story
As X-T5 사용자, I want 휴대폰 XApp 앨범과 Mac 사진 폴더를 한 번 등록해 두고 새 사진만 빠르게 읽히기를, so that 3·4단계의 장소 이름과 찾기 화면이 늘 최신 색인 위에서 동작한다.

## Metadata
- **Complexity**: Large (Dart 새 파일 6, Swift·Kotlin 채널 각 1, 화면 1, 권한·entitlement)
- **Source PRD**: `Project/recipe-slot-manager/docs/photo-log.prd.md`
- **PRD Phase**: 2. 사진 색인
- **Estimated Files**: 약 24개
- **커밋 단위**: A(색인 자료·저장·색인기), B(출처 읽기와 네이티브 채널), C(사진 화면), D(문서)

---

## 결정 필요 (승인 때 함께 정한다)

| # | 무엇 | 제안 | 다른 선택 | 이유 |
|---|---|---|---|---|
| D1 | Android 앨범 읽기 | 자체 Kotlin 채널(MediaStore) | `photo_manager` 3.12.0 | `photo_manager` 는 사진만 읽어도 `READ_MEDIA_VIDEO` 권한을 함께 요구하고, 원본은 파일 전체(`originBytes`/`originFile`)로 준다. 자체 채널은 `READ_MEDIA_IMAGES`·`ACCESS_MEDIA_LOCATION` 만 쓰고 `setRequireOriginal` 로 앞 256 KiB 만 읽는다. PTP·OCR 채널과 같은 구조라 가짜 채널로 Dart 쪽을 시험한다 |
| D2 | Mac 폴더 접근 유지 | 자체 Swift 채널(보안 범위 북마크) | `macos_secure_bookmarks` 0.3.0 | 샌드박스 앱은 고른 폴더를 그 실행 동안만 읽는다. 다음 실행에서 다시 색인하려면 북마크가 필요하다. Swift 40줄 안팎이고 OCR 채널과 같은 등록 방식이다 |
| D3 | 휴대폰 아래 탭 | "사진"을 더하고 휴대폰 아래 탭에서는 개발용 "디자인"을 뺀다(넓은 창 레일에는 남김) | 6개 모두 아래 탭 | 412 dp 폭에 6개면 "RAW 미리보기"·"사용자 설정" 글자가 잘린다. Material 아래 탭 권장 개수는 3–5개 |

---

## UX Design

### After (휴대폰)
```
┌ 사진 ─────────────────────────────┐
│ 출처                       [+ 추가] │
│  FUJIFILM XApp  (앨범) 1,204장  ⋮  │
│  ~/Pictures/X-T5 (폴더)  382장  ⋮  │
│ [새 사진 읽기]   ▓▓▓▓░░ 120 / 310  │
│ 전체 1,586 · 위치 있음 0           │
│ Eterna 412 · Classic Neg. 301 · …  │
│ (Android) 사진 위치 접근이 허용되지 │
│  않아 위치를 읽을 수 없습니다 [허용] │
└───────────────────────────────────┘
로그: 사진 색인: 새로 120, 바뀜 3, 지움 1, 실패 0, 4.2초
```

### Interaction Changes
| Touchpoint | Before | After |
|---|---|---|
| 셸 목적지 | 5개 | "사진" 추가 (D3) |
| 출처 추가 | 없음 | macOS: 폴더 고르기 → 북마크 저장. Android: 권한 요청 → 앨범 목록에서 선택 |
| 색인 | 없음 | "새 사진 읽기" 버튼, 진행 막대, 끝나면 로그 한 줄 |
| 출처 삭제 | 없음 | ⋮ → 목록에서 빼기 (해당 출처의 색인 항목도 지움, 사진 파일은 그대로) |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `lib/library/library_store.dart` | all | ChangeNotifier 저장소, `SerialQueue` 쓰기, 깨진 파일 옮기기 |
| P0 | `lib/photo/photo_info.dart` | all | 색인할 값. JSON 변환을 더한다 |
| P0 | `lib/import/text_recognizer.dart` | all | 채널 호출과 `PlatformException`·`MissingPluginException` 처리 |
| P0 | `android/.../OcrChannel.kt`, `MainActivity.kt` | all | Kotlin 채널 등록·작업 스레드·메인 스레드 응답 |
| P0 | `macos/Runner/OcrChannel.swift`, `MainFlutterWindow.swift`, `project.pbxproj` | OcrChannel 4곳 | Swift 채널 등록과 pbxproj 항목 4개 |
| P1 | `lib/ui/app_shell.dart` | 13–130 | 목적지 목록, 휴대폰 배치 |
| P1 | `lib/ui/raw_preview_page.dart` | all | 화면 구성, 안내 문구, 셸 주입 방식 |
| P1 | `test/support/test_app.dart`, `test/ui/compact_layout_test.dart` | all | 화면 시험 준비, 휴대폰 크기 넘침 시험 |
| P2 | `lib/import/file_pick.dart` | 1–35 | 256 KiB 앞부분 읽기 |

## External Documentation

| Topic | Source | Key Takeaway |
|---|---|---|
| 미디어 위치 | Android Developers "Access media files from shared storage" | Android 10+ 는 위치를 지운 사본을 준다. `ACCESS_MEDIA_LOCATION` 을 런타임에 받고 `MediaStore.setRequireOriginal(uri)` 로 연다. 권한 없이 원본을 열면 `SecurityException` |
| 이미지 읽기 권한 | 같은 문서 | Android 13+ `READ_MEDIA_IMAGES`, 12 이하 `READ_EXTERNAL_STORAGE`(`maxSdkVersion="32"`) |
| 변경 감지 | 같은 문서 | `DATE_MODIFIED` 는 바뀔 수 있다. 판단은 id·크기·수정 시각을 함께 본다 |
| 보안 범위 북마크 | Apple "Enabling Security-Scoped Bookmark and URL Access" | `bookmarkData(options: .withSecurityScope)`, 해석 뒤 `startAccessingSecurityScopedResource()`. entitlement `com.apple.security.files.bookmarks.app-scope` 필요 |
| `photo_manager` 3.12.0 | pub.dev README | (D1 대안) Android 13 에서 `READ_MEDIA_IMAGES`·`READ_MEDIA_VIDEO` 둘 다 필요, `ACCESS_MEDIA_LOCATION` 별도 |

---

## Patterns to Mirror

### STORE (ChangeNotifier + SerialQueue + 깨진 파일 옮기기)
// SOURCE: lib/library/library_store.dart:14-28, 140-175
```dart
final _writes = SerialQueue();
Future<void> _writeFile(File file, Map<String, Object> Function() json) =>
    _writes.run(() => writeJsonAtomically(file, json()));
```

### CHANNEL_CALL
// SOURCE: lib/import/text_recognizer.dart:9-18
```dart
try {
  return await ocrChannel.invokeListMethod<String>('recognize', image) ?? const [];
} on PlatformException catch (e) { throw ImportException('…: ${e.message ?? e.code}'); }
  on MissingPluginException { throw const ImportException('이 기기에서는 … 지원하지 않습니다'); }
```

### KOTLIN_CHANNEL
// SOURCE: android/.../OcrChannel.kt:21-45
작업은 `Executors.newSingleThreadExecutor()`, 응답은 `Handler(Looper.getMainLooper()).post { result.… }`.

### LOG
// SOURCE: lib/sync/sync_service.dart:86-88 — 로그는 상태 명사구 (`동기화: 다운로드 N, …`)

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `lib/import/jpeg_exif.dart` | UPDATE | `jpegHeadBytes = 256 * 1024` 를 공개 상수로 (`file_pick` 과 출처 읽기가 같이 쓴다) |
| `lib/import/file_pick.dart` | UPDATE | `_jpegHeadBytes` 대신 `jpegHeadBytes` |
| `lib/photo/photo_info.dart` | UPDATE | `toJson`/`fromJson` |
| `lib/photo/photo_source.dart` | CREATE | `PhotoSource`(id, kind 폴더/앨범, 이름, 북마크), `PhotoFile`(id, 이름, 크기, 수정 시각), `PhotoSourceReader` 인터페이스 |
| `lib/photo/photo_index_store.dart` | CREATE | 출처·색인 항목을 `photos.json` 에 저장, 요약 계산 |
| `lib/photo/photo_indexer.dart` | CREATE | 목록 비교 → 새·바뀐 사진만 읽기 → 저장, 진행 알림, 결과 |
| `lib/photo/folder_reader.dart` | CREATE | 폴더 재귀 탐색(.jpg/.jpeg), 앞부분 읽기, macOS 북마크 채널 |
| `lib/photo/album_reader.dart` | CREATE | Android 채널: 권한, 앨범 목록, 사진 목록, 앞부분 읽기 |
| `lib/ui/photos_page.dart` | CREATE | 사진 화면 |
| `lib/ui/app_shell.dart` | UPDATE | "사진" 목적지, 휴대폰에서 "디자인" 숨김(D3) |
| `lib/main.dart` | UPDATE | 저장소·출처 읽기 생성과 주입 |
| `macos/Runner/BookmarkChannel.swift` | CREATE | `create(path)`, `resolve(bookmark)`, `stop(path)` |
| `macos/Runner/MainFlutterWindow.swift`, `project.pbxproj` | UPDATE | 채널 등록, 빌드 항목 4개 |
| `macos/Runner/DebugProfile.entitlements`, `Release.entitlements` | UPDATE | `com.apple.security.files.bookmarks.app-scope` |
| `android/.../PhotoChannel.kt` | CREATE | `requestAccess`, `albums`, `photos`, `readHead` |
| `android/.../MainActivity.kt` | UPDATE | 채널 등록, 권한 결과 전달 |
| `android/app/src/main/AndroidManifest.xml` | UPDATE | `READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE`(maxSdk 32), `ACCESS_MEDIA_LOCATION` |
| `test/support/fake_photo_reader.dart` | CREATE | 메모리 안 가짜 출처 |
| `test/photo/photo_index_store_test.dart`, `photo_indexer_test.dart`, `folder_reader_test.dart`, `album_reader_test.dart` | CREATE | |
| `test/photo/photo_info_test.dart` | UPDATE | JSON 왕복 |
| `test/ui/photos_page_test.dart` | CREATE | |
| `test/ui/compact_layout_test.dart`, `test/ui/library_flow_test.dart`, `test/support/test_app.dart` | UPDATE | 목적지 변경, 사진 화면 주입 |
| `docs/unverified.md`, `docs/photo-log.prd.md` | UPDATE | 미확인 항목, 상태와 계획 연결, 1단계 complete |

## NOT Building

- 주소 변환(3단계), 필터·지도·썸네일·사진 상세(4단계), Supabase 동기화(6단계)
- 자동 색인(앱 시작·백그라운드) — 버튼으로만 한다
- Android 폴더 직접 고르기(SAF) — MediaStore 앨범만
- HEIC·RAF 색인

---

## Step-by-Step Tasks

### A1: `PhotoInfo` JSON
- **IMPLEMENT**: `toJson()` → `{shotAt: '2026-10-11T15:26:10', utcOffsetMinutes: 540, latitude, longitude, model, imageCount, recipe: {..}}`, 없는 값은 키를 뺀다. `PhotoInfo.fromJson(Object?)` 형식이 맞지 않으면 `FormatException('사진 정보 형식 오류')`
- **MIRROR**: `lib/recipe/recipe.dart` 의 `toJson`/`fromJson`
- **VALIDATE**: 왕복 시험(모든 필드, 빈 값), 깨진 JSON

### A2: 출처·항목 모델 (`photo_source.dart`)
- `PhotoSource({id, kind, name, bookmark?})`, `kind` 는 `enum PhotoSourceKind { folder, album }`
- `PhotoFile = ({String id, String name, int size, int modifiedMs})` — id 는 폴더면 출처 안 상대 경로, 앨범이면 `content://` URI
- `IndexedPhoto({sourceId, file: PhotoFile, info: PhotoInfo?, error: String?, locationRedacted: bool})`
- `abstract interface class PhotoSourceReader { Future<List<PhotoFile>> list(PhotoSource); Future<PhotoHead> readHead(PhotoSource, PhotoFile); }`, `PhotoHead = ({Uint8List bytes, bool locationRedacted})`

### A3: `PhotoIndexStore`
- `photos.json` = `{sources: [..], photos: [..]}`. `load`, `addSource`, `removeSource`(항목도 삭제), `replaceSource(sourceId, photos, indexedAt)`
- 요약: `total`, `withLocation`, `byFilmSimulation`(코드 → 수), `failed`
- 깨진 파일은 `photos.json.corrupt-<시각>` 으로 옮기고 `loadErrors` (LibraryStore 와 같은 방식)
- **GOTCHA**: 수천 항목이므로 `replaceSource` 는 출처 하나당 쓰기 1번

### A4: `PhotoIndexer.index(source, {onProgress})`
- 목록을 받아 기존 항목과 id 로 비교: 크기·수정 시각이 같고 `locationRedacted` 가 아니면 그대로 둔다. 새 것·바뀐 것·위치가 가려졌던 것(지금은 원본을 읽을 수 있을 때)만 `readHead` → `readPhotoInfo`
- `ImportException` 은 항목의 `error` 로 남긴다(같은 파일은 바뀌기 전까지 다시 읽지 않는다)
- 목록에 없는 기존 항목은 지운다
- 결과 `({int added, int changed, int removed, int failed, Duration elapsed})`, 로그 `사진 색인: 새로 N, 바뀜 N, 지움 N, 실패 N, N.N초`
- `onProgress(done, total)` 는 읽을 사진 수 기준
- **GOTCHA**: 출처 읽기 실패(폴더 없음, 권한 없음)는 `PhotoSourceException` 으로 던지고 색인을 바꾸지 않는다

### B1: 폴더 읽기 (`folder_reader.dart`)
- `list`: 출처 경로 아래를 재귀 탐색, 확장자 `.jpg`/`.jpeg`(대소문자 무시), 숨김 파일 제외, `stat` 으로 크기·수정 시각
- `readHead`: `RandomAccessFile` 로 `jpegHeadBytes` 만
- macOS: `list` 앞에 북마크를 `resolve` 해 경로와 접근 권한을 얻고 끝나면 `stop`. 북마크가 오래되면(`isStale`) 새 북마크를 돌려받아 출처를 갱신
- 폴더 추가: `file_selector` `getDirectoryPath()` → `create(path)` 로 북마크
- **VALIDATE**: 임시 폴더 시험(하위 폴더, 대문자 확장자, 숨김 파일, PNG 제외). 북마크 채널은 가짜 채널로

### B2: Swift `BookmarkChannel`
- 채널 `recipe_slot_manager/bookmarks`. `create(path) → FlutterStandardTypedData`, `resolve(bookmark) → {path, stale, bookmark?}` 후 `startAccessingSecurityScopedResource`, `stop(path)`
- entitlement 두 파일에 `com.apple.security.files.bookmarks.app-scope`
- pbxproj: OcrChannel 처럼 PBXBuildFile·PBXFileReference·그룹·Sources 4곳

### B3: Kotlin `PhotoChannel` (D1)
- 채널 `recipe_slot_manager/photos`
- `requestAccess` → `{images: bool, location: bool}`. API 33+ `READ_MEDIA_IMAGES`, 미만 `READ_EXTERNAL_STORAGE`, API 29+ `ACCESS_MEDIA_LOCATION`. `MainActivity.onRequestPermissionsResult` 를 채널로 넘긴다
- `albums` → `[{id: BUCKET_ID, name: BUCKET_DISPLAY_NAME, count}]` (MIME `image/jpeg`)
- `photos(albumId)` → `[{id: uri, name, size, modified(ms)}]`
- `readHead(id, length)` → `{bytes, locationRedacted}`. 위치 권한이 있으면 `setRequireOriginal`, `SecurityException` 이면 일반 URI 로 읽고 `locationRedacted: true`
- 작업 스레드에서 쿼리·읽기, 메인 스레드로 응답

### B4: 앨범 읽기 (`album_reader.dart`)
- 채널 응답을 `PhotoFile`·`PhotoHead` 로. 권한 없음은 `PhotoSourceException('사진 접근이 허용되지 않았습니다')`
- **VALIDATE**: `TestDefaultBinaryMessengerBinding` 가짜 채널로 인자·변환·오류

### C1: 사진 화면 (`photos_page.dart`)
- 출처 목록(이름, 종류, 사진 수, 마지막 색인 시각), 추가, 목록에서 빼기(확인 대화상자)
- "새 사진 읽기": 출처마다 차례로 색인, 진행 막대, 다른 색인 중이면 버튼 끔
- 요약: 전체·위치 있음·실패, 필름 시뮬레이션별 수(많은 순, 이름은 `fieldById['filmSimulation'].display`)
- Android 위치 권한이 없으면 안내와 "허용" 버튼
- 출처 추가·폴더 고르기는 함수로 주입(시험에서 가짜로)

### C2: 셸
- 목적지 `사진`(Icons.photo_library_outlined)을 RAW 미리보기 뒤에. 휴대폰 배치 아래 탭에서는 "디자인" 제외(D3)
- `main.dart`: `PhotoIndexStore(Directory(support/photos))`, 플랫폼별 출처 읽기

### D1: 문서
- `docs/unverified.md` "사진 기록 2단계" 절, PRD 1단계 complete·2단계 in-progress·계획 연결

---

## Testing Strategy

| Test | Input | Expected |
|---|---|---|
| 첫 색인 | 가짜 출처 3장 | 3장 저장, added 3, readHead 3번 |
| 다시 색인, 변화 없음 | 같은 목록 | readHead 0번 |
| 바뀐 사진 | 1장 크기 변경 | readHead 1번, changed 1 |
| 사라진 사진 | 1장 목록에서 빠짐 | 항목 삭제, removed 1 |
| 해석 실패 | JPEG 아님 | error 저장, failed 1, 다음 색인에서 다시 읽지 않음 |
| 위치 가려짐 | locationRedacted 로 읽힌 사진, 다음엔 원본 | 두 번째 색인에서 다시 읽음 |
| 출처 읽기 실패 | list 가 던짐 | 기존 색인 유지, 예외 전달 |
| 진행 | 5장 | onProgress (1,5)…(5,5) |
| 100장 | 가짜 100장 | 10초 안 (가짜 기준. 실기기는 미확인) |
| 저장소 왕복 | 출처 2, 항목 n | load 뒤 같음, 깨진 파일 옮김 |
| 출처 빼기 | | 해당 항목만 삭제 |
| 요약 | Eterna 2·Classic Neg. 1·위치 1 | 값 일치 |
| 폴더 탐색 | 임시 폴더 | 하위 폴더·`.JPG` 포함, 숨김·PNG 제외, 앞 256 KiB 만 |
| 앨범 채널 | 가짜 채널 | 변환, 권한 없음 오류, 플러그인 없음 오류 |
| 화면 | 출처 추가 → 새 사진 읽기 | 진행 뒤 요약·로그, 휴대폰 3크기 넘침 없음, 아래 탭에 "디자인" 없음 |

---

## Validation Commands

```bash
cd Project/recipe-slot-manager
flutter analyze
dart format --set-exit-if-changed lib test tool
flutter test
flutter build macos --debug
flutter build apk --debug
```

## Acceptance Criteria
- [ ] Testing Strategy 시험 통과, 기존 시험 통과(목적지 변경 반영)
- [ ] macOS·Android 디버그 빌드 성공
- [ ] 같은 출처를 두 번 색인하면 두 번째는 파일을 읽지 않는다

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Android 14+ "일부 사진만 허용"을 고르면 일부만 보인다 | M | M | 화면에 보이는 수를 그대로 보이고 미확인 항목에 남긴다 |
| XApp 앨범 이름을 모른다 | M | L | 앨범 목록에서 고른다 |
| 수천 장 첫 색인이 오래 걸린다 | M | M | 진행 표시, 다음부터는 바뀐 것만. 실기기 측정은 미확인 |
| 북마크가 오래됨 | L | M | `stale` 이면 새 북마크로 출처 갱신 |
| 위치 권한 거부 | M | M | `locationRedacted` 로 남기고 허용 뒤 다시 읽는다 |

---

## 구현 중 바뀐 점

- 위치가 가려진 채 읽은 사진은 다음 색인에서 늘 다시 읽는다. 원본을 읽을 수 있는지는 읽어 봐야 알기 때문이다
- 출처 고르기는 `lib/ui/photo_source_picker.dart`(macOS 폴더, Android 앨범 대화상자)로 나눴다
- 휴대폰에서 디자인 화면을 보던 중이면 첫 탭(레시피)을 보이고, 창이 넓어지면 디자인으로 돌아간다
- 디자인 화면의 휴대폰 크기 넘침 시험은 셸 대신 화면을 직접 띄워 확인한다
