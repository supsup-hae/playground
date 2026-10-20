# Plan: 위치 기록 (사진 기록 5단계)

## Summary
세트를 카메라 C1–C7에 저장하면 그때의 휴대폰 위치, 세트 이름, 슬롯별 레시피 이름, 시각을 기록 하나로 남긴다. 위치는 Android 에서만 받고, 권한이 없거나 위치를 받지 못해도 저장은 그대로 끝나며 기록은 위치 없이 남는다. 기록은 사진 탭의 세 번째 보기 "기록"에서 최신순으로 보고, 사진 탭 지도에 사진 점과 다른 모양으로 겹쳐 본다. 기록 좌표의 장소 이름은 사진과 같은 캐시(`places.json`)와 주소 변환을 쓴다.

## User Story
As X-T5 사용자, I want 세트를 바꿀 때마다 어디서 바꿨는지 남기기를, so that 그 장소에서 어떤 레시피로 찍었는지 사진과 함께 다시 본다.

## Metadata
- **Complexity**: Medium
- **Source PRD**: `Project/recipe-slot-manager/docs/photo-log.prd.md`
- **PRD Phase**: 5. 위치 기록
- **새 의존성**: 없음. Android 위치는 `LocationManager`(플랫폼 API)로 받는다. Google Play 서비스(`play-services-location`)는 쓰지 않는다

---

## 결정 필요 (승인 때 함께 정한다)

| # | 무엇 | 제안 | 다른 선택 | 이유 |
|---|---|---|---|---|
| D1 | 기록하는 저장 | 세트 저장(C1–C7 한꺼번에)만 | 사용자 설정 탭의 슬롯 하나 저장도 기록 | PRD 범위가 "세트 쓰기"다. 슬롯 하나 저장은 값을 고치는 중간 단계라 기록이 많아진다 |
| D2 | Mac | Mac 에서도 기록은 남기고 위치 칸만 비운다 | Mac 에서는 기록하지 않음 | "언제 어떤 세트를 넣었나"는 위치 없이도 쓸모가 있고, macOS 위치 권한을 들이지 않는다 |
| D3 | 위치 권한을 묻는 때 | 세트 화면에서 "C1–C7에 저장"을 처음 누를 때, 쓰기 전에 묻는다. 거부하면 이후 묻지 않고 위치 없이 기록한다(Android 가 두 번 거부 뒤 창을 띄우지 않는다) | 앱을 열 때, 설정에 켜기 스위치 | 위치가 필요한 순간에 물어야 왜 묻는지 알 수 있다. 카메라 쓰기 도중에는 창을 띄우지 않는다 |
| D4 | 기록 목록과 지도 | **사용자 결정(2026-10-20)**: 사진 탭에 세 번째 보기 "기록"(목록 \| 지도 \| 기록). 지도에는 "세트 저장 위치" 칩으로 기록 점을 겹친다. 사진 찾기 조건 중 연도·지역·검색어를 기록에도 적용한다(필름 시뮬레이션·위치 없음은 사진에만) | 세트 탭의 "저장 기록" 화면 | 사진과 기록을 같은 조건으로 한 탭에서 오가며 본다 |

---

## UX Design

### 사진 탭 기록 보기
```
┌ 사진 ──────────────────── [출처] ┐
│ [ 목록 | 지도 | 기록 ]             │
│ … 검색·연도·지역 (필름 칩은 숨김) │
│ 2026-10-20                         │
│  14:03  도쿄 밤                     │
│         일본 도쿄도 시부야구 진난    │
│         C1 Eterna 밤 · C2 Classic … │
│  09:12  아침 산책                   │
│         위치 없음                   │
└────────────────────────────────────┘
```

### 사진 탭 지도
```
[ 목록 | 지도 ]  … 필터 줄 …  [세트 저장 위치]   ← 칩, 지도 보기에서만
지도: 사진 묶음 점(원, 수) + 기록 점(사각 아이콘). 기록 점을 누르면 시트에 시각·세트·슬롯 이름
```

### Interaction Changes
| Touchpoint | Before | After |
|---|---|---|
| 세트 → C1–C7에 저장 | 저장만 | (Android) 처음 한 번 위치 권한 → 저장 → 기록 하나. 로그 `저장 기록: 일본 도쿄도 …` 또는 `저장 기록: 위치 없음 (이유)` |
| 사진 탭 | 목록·지도 | 목록·지도·기록 |
| 사진 지도 | 사진 점 | "세트 저장 위치" 칩으로 기록 점 겹치기 |

---

## Mandatory Reading

| Priority | File | Why |
|---|---|---|
| P0 | `lib/ui/apply_loadout_page.dart` | `_write` 성공 뒤 기록. `session.run` 이 실패 문구를 돌려준다 |
| P0 | `lib/photo/place_store.dart` | 기록 저장소가 따를 모양(`load`·깨진 파일 옮기기·`SerialQueue`·`writeJsonAtomically`) |
| P0 | `lib/photo/place_resolver.dart`, `photo_indexer.dart` | 기록 좌표도 이름을 묻게 한다. `indexAll` 의 `resolveMissing` 과 겹치지 않게 |
| P0 | `lib/photo/geocoder.dart`, `android/.../GeocoderChannel.kt`, `PhotoChannel.kt`(권한 요청), `MainActivity.kt` | 채널·권한 결과 넘기기 방식 |
| P1 | `lib/ui/photo_map_view.dart`, `photos_page.dart`, `photo_query.dart` | 지도 겹치기, 조건 적용 |
| P1 | `lib/ui/app_shell.dart`, `lib/main.dart` | 연결 |
| P2 | `test/support/test_app.dart`, `fake_geocoder.dart`, `test/ui/*loadout*` | 화면 시험 준비 |

## External Documentation

| Topic | Source | Key Takeaway |
|---|---|---|
| `LocationManager.getCurrentLocation` | developer.android.com | API 30+. `(provider, CancellationSignal, Executor, Consumer<Location?>)`. 결과가 null 일 수 있다. API 31+ `FUSED_PROVIDER` |
| 위치 권한 | developer.android.com | `ACCESS_FINE_LOCATION` 과 `ACCESS_COARSE_LOCATION` 을 함께 요청하면 Android 12+ 는 "대략적 위치"를 고를 수 있다. 거부 두 번 뒤에는 요청 창이 뜨지 않는다 |

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `lib/photo/place_log.dart` | CREATE | `PlaceLog`(id, loggedAt UTC, utcOffset, location?, accuracy?, loadoutId, loadoutName, slots(7칸 레시피 이름, null = 그대로), model?, missingReason?) JSON |
| `lib/photo/place_log_store.dart` | CREATE | `place_logs.json`(사진 폴더 안), `logs`(최신순), `add`. `PlaceStore` 와 같은 불러오기·깨진 파일 처리 |
| `lib/photo/locator.dart` | CREATE | `Locator` 인터페이스(`requestAccess`, `current`), `PlatformLocator`(채널 `recipe_slot_manager/location`, 시간 제한 15초), `LocateException(code)` |
| `lib/photo/place_logger.dart` | CREATE | 저장 뒤 위치 받기 → 기록 저장 → 로그 → 장소 이름 묻기. 어떤 실패도 밖으로 던지지 않는다 |
| `lib/photo/place_resolver.dart` | UPDATE | 기록 좌표도 포함. `resolveMissing` 을 한 번에 하나만 돌린다(`SerialQueue`) |
| `lib/photo/photo_query.dart` | UPDATE | `queryPlaceLogs(logs, places, filter)`: 연도·지역·검색어 |
| `lib/ui/apply_loadout_page.dart` | UPDATE | 저장 전 권한 확인, 저장 성공 뒤 기록 |
| `lib/ui/place_log_list_view.dart` | CREATE | 사진 탭 기록 보기: 날짜별 기록 목록 |
| `lib/ui/photo_map_view.dart`, `photos_page.dart`, `photos_setup.dart` | UPDATE | 기록 점, 칩, 기록 저장소 |
| `lib/ui/app_shell.dart`, `lib/main.dart` | UPDATE | 연결 (macOS 는 `locator: null`) |
| `android/.../LocationChannel.kt`, `MainActivity.kt`, `AndroidManifest.xml` | CREATE/UPDATE | 위치 권한·현재 위치 |
| 시험: `place_log_test`, `place_log_store_test`, `locator_test`, `place_logger_test`, `place_resolver_test`, `photo_query_test`, 화면 시험 | CREATE/UPDATE | |
| `docs/photo-log.prd.md`, `docs/unverified.md` | UPDATE | 4단계 완료, 5단계 진행·미확인 항목 |

## NOT Building
- 슬롯 하나 저장의 기록(D1), macOS 위치(D2)
- 기록 지우기·고치기 — 필요하면 다음에 더한다
- 백그라운드 위치, 위치 이력 추적 — 저장하는 순간 한 번만 받는다
- 동기화(6단계). 다만 `id` 를 두어 6단계에서 그대로 올린다

---

## Step-by-Step Tasks

- **L1 `PlaceLog`·JSON**: 7칸이 아니거나 형식이 틀리면 `FormatException`. `localTime`(= loggedAt + utcOffset) 은 연도 조건과 화면에 쓴다
- **L2 `PlaceLogStore`**: `PlaceStore` 와 같은 모양. `add` 는 저장 뒤 알림
- **L3 `Locator`(Dart)**: `current()` → `({GeoPoint point, double? accuracy})?`. `PlatformException` → `LocateException(code)`, 시간 초과 → `timeout`, 플러그인 없음 → `unavailable`. `requestAccess()` → bool
- **L4 `PlaceLogger.record(loadout, slotNames, model)`**: `locator` 가 null 이면 위치 없이. `current()` 실패는 `missingReason` 에 남기고 위치 없이 저장. 저장 실패(`FileSystemException`)는 로그만. 저장 뒤 `resolver.resolveMissing()`. 로그 `저장 기록: <장소 또는 좌표>` / `저장 기록: 위치 없음 (<이유>)`
- **L5 `PlaceResolver`**: 사진 좌표 + 기록 좌표. 겹친 호출은 앞 호출이 끝난 뒤 돈다(이미 받은 키는 다시 묻지 않음)
- **L6 `queryPlaceLogs`**: `PhotoFilter` 의 year·country·admin·locality·text 만 본다. 기록이 위치 없으면 지역 조건이 있을 때 빠진다
- **L7 Kotlin `LocationChannel`**: `requestAccess` → 이미 있으면 true, 아니면 FINE+COARSE 요청(요청 코드 4031), 결과는 `MainActivity.onRequestPermissionsResult` 가 넘긴다. `current` → 권한 없으면 `denied`, 위치 꺼짐이면 `disabled`. API 31+ `FUSED_PROVIDER`, 30 은 GPS·NETWORK 중 켜진 것으로 `getCurrentLocation`, 29 이하는 가장 최근 `getLastKnownLocation`. 결과 `{latitude, longitude, accuracy}` 또는 null(`unavailable`)
- **L8 세트 저장 화면**: `_write` 앞에서 `logger?.prepare()`(권한 요청, 결과와 상관없이 계속). 성공(`failure == null`) 뒤 `unawaited(logger.record(...))` — 저장 화면은 기록을 기다리지 않는다. 슬롯 이름은 `library.slotRecipes(loadout)` 의 `recipe?.name`
- **L9 기록 보기**: 사진 탭 `SegmentedButton` 에 "기록". 필름 칩·위치 없음 칩은 숨긴다. 날짜 묶음(`formatDate`), 줄마다 시각·세트 이름·장소 `label`(없으면 좌표, 위치 없으면 "위치 없음")·슬롯 이름. 비었으면 "세트를 카메라에 저장하면 여기에 기록됩니다"
- **L10 지도 겹치기**: `PhotoMapView(logs: …)`. 기록 점은 묶지 않고 아이콘 마커(`ValueKey('log-<id>')`), 누르면 시트. 사진 점이 없고 기록만 있으면 기록 점에 맞춰 화면을 맞춘다. 칩 상태는 `PhotosSetup` 의 `ValueNotifier<bool>`

---

## Testing Strategy

| Test | Expected |
|---|---|
| `PlaceLog` JSON 왕복, 7칸 아님·형식 오류 | `FormatException` |
| 저장소 왕복, 파일 없음, 깨진 파일 옮기기 | `PlaceStore` 시험과 같은 항목 |
| `PlatformLocator`: 정상, `denied`·`disabled` 오류, 시간 초과, 플러그인 없음 | 가짜 채널 |
| `PlaceLogger`: 위치 받음 → 좌표·정확도 저장, 위치 실패 → 이유와 함께 위치 없이 저장, locator 없음, 저장 실패는 던지지 않음, 저장 뒤 장소 이름 요청 | 가짜 Locator·Geocoder |
| `PlaceResolver`: 기록 좌표 포함, 동시 호출이 같은 키를 두 번 묻지 않음 | |
| `queryPlaceLogs`: 연도(현지 시각 기준), 지역, 검색어, 필름 조건 무시 | |
| 화면: 세트 저장 성공 → 기록 하나, 저장 실패 → 기록 없음, 권한 거부여도 저장됨, 기록 보기 목록·빈 상태, 지도 칩으로 기록 점 표시·누르면 시트, 휴대폰 크기 넘침 없음 | 가짜 카메라 |

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
| 실내·지하에서 위치를 15초 안에 못 받는다 | M | L | 위치 없이 기록하고 이유를 남긴다. 저장 화면은 기다리지 않는다 |
| "대략적 위치"만 허용하면 골목 단위가 아니다 | M | M | 정확도(m)를 저장하고 화면에 "약 N m" 를 보인다 |
| 위치 권한 창이 카메라 USB 권한 창과 겹친다 | L | M | 저장 전에 묻고, 결과를 받은 뒤 쓰기를 시작한다 |
| 실기기 확인 불가 | H | M | 가짜 채널 시험, `docs/unverified.md` 항목 |

---

## 구현 중 바뀐 점

- 저장 직후 로그에는 장소 이름 대신 좌표와 오차 반경을 남긴다(`저장 기록: <세트> · 35.6587, 139.7005 (약 12 m)`). 장소 이름은 그 뒤 주소 변환이 캐시에 넣고, 기록 보기가 캐시에서 읽는다
- 위치 권한은 "C1–C7에 저장"을 누를 때마다 확인한다. 이미 허용했거나 두 번 거부한 뒤에는 창이 뜨지 않아 바로 넘어간다
- 기록 보기의 연도·지역 선택지는 기록에서 만든다(`placeLogFacets`). 사진 쪽 선택지와 같은 함수를 공유한다
- `PlaceLogger` 는 셸 → 세트 목록 → 세트 저장 화면으로 넘긴다
