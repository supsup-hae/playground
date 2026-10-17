# Plan: 보관함·묶음·비교 (2단계, macOS)

## Summary
레시피를 사람이 읽는 값(필름 시뮬레이션, 하이라이트 +1.5 등)으로 만들고 보관하며, 상황별로 C1–C7에 넣을 레시피 7개를 묶고, 카메라의 현재 슬롯과 비교한 뒤 7슬롯을 한 번에 덮어쓴다. 카메라 다이얼풍 디자인 시스템을 먼저 만들고 그 위에 화면을 올린다. 기기에는 JSON 파일로 저장하고, Supabase(이메일 OTP 로그인)와 동기화한다. 실기기 시험이 불가하므로 모든 동작은 가짜 전송과 단위·위젯 시험으로 검증한다.

## User Story
As X-T5 사용자, I want 장면별 레시피 묶음을 골라 바뀌는 값을 확인하고 7슬롯을 한 번에 쓰기를, so that 촬영 중 카메라 메뉴에서 값을 손으로 바꾸지 않는다.

## Problem → Solution
1단계 화면은 원시 16진수 값만 다루고 한 슬롯씩 쓴다 → 레시피·묶음을 저장하고, 묶음을 고르면 슬롯별로 바뀌는 항목을 사람이 읽는 값으로 보여 준 뒤 7슬롯을 한 번에 쓴다.

## Metadata
- **Complexity**: XL (새 하위 시스템 넷: 디자인, 레시피 모델, 저장·동기화, 화면)
- **Source PRD**: `Project/recipe-slot-manager/docs/prd.md`
- **PRD Phase**: 2. 보관함·묶음·비교 (+ 디자인 시스템, 사용자 결정 2026-10-17)
- **Estimated Files**: 약 40개 (Dart 25, 시험 13, SQL 1, 설정 2)
- **커밋 단위**: 작업 묶음 A–F 마다 하나 이상

---

## UX Design

### Before
```
[원시 값 표] C1..C7 × D18E..D1A5 16진수 → 셀 하나 수정 → "C7 쓰기"
```

### After
```
┌ ◉ 보관함 ┬──────────────────────────────────────────────┐
│ ◎ 묶음   │  야간 거리 (묶음)                    [비교 →]  │
│ ◎ 카메라 │  C1 Kodak Portra   C2 Classic Neg  … C7 Acros │
│ ─────    ├──────────────────────────────────────────────┤
│ ◎ 원시값 │  비교: C2  Classic Neg → Nostalgic Neg       │
│ ◎ 디자인 │        하이라이트 -1 → +0.5  (주황 표시)       │
│ ⟳ 동기화 │        그레인 약·소 → 강·대                   │
│          │                         [ 7슬롯 쓰기 ] 4.2s  │
└──────────┴──────────────────────────────────────────────┘
레시피 편집: 값마다 가로 눈금 다이얼(드래그·클릭·←→), 선택형은 노브 세그먼트
```
어두운 바탕, 눈금·숫자는 고정폭 숫자, 강조색은 다이얼 주황 하나. 바뀌는 값만 강조색을 쓴다.

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| 레시피 값 입력 | 16진수 셀 | 눈금 다이얼·노브 | 범위·간격은 필드 표 한 곳에서 정함 |
| 슬롯 쓰기 | 한 슬롯씩 | 묶음 7슬롯 한 번에 | 쓰기 전 새로 읽기 + 백업 (1단계 규칙 유지) |
| 바뀌는 값 확인 | 없음 | 슬롯별 비교 목록 | 사람이 읽는 값으로 |
| 저장 | 백업 JSON 만 | 레시피·묶음 보관 + 동기화 | 오프라인이면 기기 저장만 |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `lib/camera/fuji_camera.dart` | 전체 | 슬롯 읽기·쓰기·검증, `_keepingSelectedSlot`, 시간 측정 |
| P0 | `lib/camera/slot_snapshot.dart` | 전체 | 원시 값 모델, `fromJson` 검증 방식(패턴 매칭 + FormatException) |
| P0 | `lib/camera/slot_backup_store.dart` | 18–35 | 임시 파일에 쓰고 옮기는 저장 방식 (공용으로 뺌) |
| P0 | `lib/ui/slots_page.dart` | 32–60 | `_run` 오류 처리, `mounted` 검사, `clearSlotsOnError` |
| P1 | `lib/camera/prop_value.dart` | 전체 | 바이트 ↔ 정수 변환, 범위 검사 |
| P1 | `test/support/fake_ptp_transport.dart` | 전체 | 가짜 카메라. 2단계 시험도 이것을 쓴다 |
| P1 | `test/ui/slots_page_test.dart` | 40–62 | 위젯 시험의 화면 크기 설정, `tapAndWait` |
| P2 | [filmkit `src/profile/preset-translate.ts`](https://github.com/eggricesoy/filmkit/blob/master/src/profile/preset-translate.ts) | 70–180, 282–377 | 슬롯 속성 인코딩과 쓰기 순서 (MIT) |
| P2 | [filmkit `src/profile/enums.ts`](https://github.com/eggricesoy/filmkit/blob/master/src/profile/enums.ts) | 전체 | 필름 시뮬레이션·WB 모드 값 |

## External Documentation

| Topic | Source | Key Takeaway |
|---|---|---|
| 슬롯 속성 인코딩 | filmkit preset-translate.ts | 아래 "레시피 필드 표" 참조 |
| 쓰기 순서 | filmkit `translateUIToPresetProps` | `D19C`(색온도)는 `D199`(WB 모드) 바로 뒤, `D19A/D19B`(WB 시프트)보다 먼저 |
| 조건부 속성 | 같은 곳 | 색온도는 WB=색온도(0x8007)일 때만. 컬러(D19F)는 흑백 시뮬레이션이면 쓰지 않음. 모노 WC/MG(D193/D194)는 흑백일 때만, 0은 카메라가 거부 |
| 톤 값 센티넬 | 같은 곳 | ×10 속성의 0x8000은 "값 없음". 0으로 취급하지 말고 원래 바이트를 유지 |
| supabase_flutter | pub.dev `supabase_flutter` | `Supabase.initialize(url, anonKey)`, `auth.signInWithOtp(email)`, `auth.verifyOTP(type: OtpType.email, email, token)`, `from(table).upsert(rows)`, `.select().gt('updated_at', t)` |
| macOS 네트워크 | Apple App Sandbox | 샌드박스 앱이 Supabase에 접속하려면 `com.apple.security.network.client` 엔타이틀먼트 필요 |

### 레시피 필드 표 (`lib/recipe/recipe_fields.dart` 한 곳에 둔다)

| 필드 | 속성 | 인코딩 | 범위·간격 (조정 가능) |
|---|---|---|---|
| 필름 시뮬레이션 | D192 | u16 열거 (Provia 0x01 … Reala Ace 0x14) | 목록 |
| 다이내믹 레인지 | D190 | u16 퍼센트 100/200/400 | 목록 |
| 그레인 | D195 | u16 1=끔, 2=약·소, 3=강·소, 4=약·대, 5=강·대 | 목록 |
| 컬러 크롬 | D196 | u16 1=끔, 2=약, 3=강 | 목록 |
| 컬러 크롬 FX 블루 | D197 | 같음 | 목록 |
| 스무스 스킨 | D198 | 같음 | 목록 |
| WB 모드 | D199 | u16 열거 (Auto 0x0002, Daylight 0x0004, 색온도 0x8007 …) | 목록 |
| 색온도 | D19C | u16 켈빈 | 2500–10000, 10 |
| WB 시프트 R / B | D19A / D19B | i16 | -9–+9, 1 |
| 하이라이트 / 섀도 | D19D / D19E | i16 ×10 | -2–+4, 0.5 |
| 컬러 | D19F | i16 ×10 | -4–+4, 1 |
| 샤프니스 | D1A0 | i16 ×10 | -4–+4, 1 |
| 고감도 NR | D1A1 | u16 표: -4=0x8000, -3=0x7000, -2=0x4000, -1=0x3000, 0=0x2000, 1=0x1000, 2=0x0000, 3=0x6000, 4=0x5000 | -4–+4, 1 |
| 클래리티 | D1A2 | i16 ×10 | -5–+5, 1 |
| 모노 WC / MG | D193 / D194 | i16 ×10 | -18–+18, 1 |

레시피가 다루지 않는 속성(D18E, D18F, D191, D1A3–D1A5)은 카메라 현재 값을 그대로 둔다.

---

## Patterns to Mirror

### NAMING_CONVENTION
// SOURCE: lib/ptp/ptp_codes.dart:18-31
```dart
abstract final class FujiProp {
  static const presetSlot = 0xD18C;
  ...
  static final presetProps = List<int>.unmodifiable([...]);
}
```
상수 묶음은 `abstract final class`, 목록은 `List.unmodifiable`.

### ERROR_HANDLING
// SOURCE: lib/camera/slot_snapshot.dart:16-36
```dart
factory SlotSnapshot.fromJson(Object? json) {
  if (json case {'slot': final int slot, ...} when slot >= 1 && ...) { ... }
  throw FormatException('슬롯 형식이 맞지 않다', json);
}
```
외부에서 들어온 JSON(파일, Supabase)은 패턴 매칭으로 검사하고 `FormatException`. `as` 캐스트를 쓰지 않는다.

// SOURCE: lib/ui/slots_page.dart:35-60 — 화면 작업은 `_run(label, action)` 으로 감싸 `PtpTransportException`, `SlotWriteException`, `FileSystemException`, `FormatException` 을 로그로 바꾼다. 2단계 화면은 이 함수를 공용으로 뺀 것을 쓴다.

### LOGGING_PATTERN
// SOURCE: lib/camera/camera_log.dart:1-8 — `CameraLog.add(message)`. 2단계도 같은 로그를 쓰고 화면 하단 로그 패널을 공유한다.

### REPOSITORY_PATTERN
// SOURCE: lib/camera/slot_backup_store.dart:18-35 — 디렉터리를 생성자로 받고, `.tmp` 에 `flush: true` 로 쓴 뒤 `rename`. 2단계 저장소도 이 함수를 쓴다 (`lib/util/atomic_json.dart` 로 옮김).

### TEST_STRUCTURE
// SOURCE: test/camera/fuji_camera_test.dart:18-35, test/ui/slots_page_test.dart:40-62
```dart
transport = FakePtpTransport(slots: sevenSlots(), currentSlot: 3);
camera = FujiCamera(transport, slotSwitchDelay: Duration.zero);
...
tester.view..physicalSize = const Size(1800, 1400)..devicePixelRatio = 1;
await tapAndWait(tester, find.text('연결'));
```
시간은 `clock` 함수 주입, 파일은 `Directory.systemTemp.createTempSync`. 위젯 시험의 가짜 시계는 `tester.pump(Duration(milliseconds: 1))` 로 흘린다.

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `lib/ptp/ptp_codes.dart` | UPDATE | `FujiProp.writeOrder` 추가 |
| `lib/camera/fuji_camera.dart` | UPDATE | 쓰기 순서 적용, `writeSlots` (7슬롯 일괄, 전체 시간) |
| `lib/util/atomic_json.dart` | CREATE | 임시 파일에 쓰고 옮기기 (백업·보관함 공용) |
| `lib/camera/slot_backup_store.dart` | UPDATE | `atomic_json` 사용 |
| `lib/design/tokens.dart` | CREATE | 색·글꼴·간격·모서리 토큰 |
| `lib/design/app_theme.dart` | CREATE | 토큰으로 `ThemeData` 구성 (어두운 테마 하나) |
| `lib/design/dial_scale.dart` | CREATE | 가로 눈금 다이얼 (숫자 값) |
| `lib/design/knob_selector.dart` | CREATE | 노브 세그먼트 (목록 값) |
| `lib/design/slot_badge.dart` | CREATE | C1–C7 표시 |
| `lib/design/change_row.dart` | CREATE | 비교 행 (이전 → 이후, 바뀐 값 강조) |
| `lib/recipe/recipe_fields.dart` | CREATE | 위 필드 표 (속성, 인코딩, 범위, 이름) |
| `lib/recipe/recipe.dart` | CREATE | 레시피 모델 (불변, JSON, 버전 필드 `updatedAt`, `deletedAt`) |
| `lib/recipe/recipe_codec.dart` | CREATE | 슬롯 ↔ 레시피 변환, 조건부 속성, 알 수 없는 값 보존 |
| `lib/recipe/recipe_diff.dart` | CREATE | 두 레시피의 바뀐 필드 목록 |
| `lib/library/loadout.dart` | CREATE | 묶음 모델 (슬롯 7칸에 레시피 id 또는 비움) |
| `lib/library/library_store.dart` | CREATE | 레시피·묶음 JSON 파일 저장소 (변경 알림 `ChangeNotifier`) |
| `lib/sync/supabase_config.dart` | CREATE | `--dart-define` 으로 받은 URL·anon key |
| `lib/sync/sync_service.dart` | CREATE | 올리기·내려받기, 최근 수정 우선 병합 |
| `lib/sync/remote_library.dart` | CREATE | 원격 저장소 인터페이스 + Supabase 구현 |
| `lib/ui/run_guard.dart` | CREATE | `_run` 공용화 |
| `lib/ui/app_shell.dart` | CREATE | 왼쪽 탐색 (보관함, 묶음, 카메라, 원시 값, 디자인, 동기화) |
| `lib/ui/recipe_list_page.dart`, `recipe_editor_page.dart` | CREATE | 레시피 목록·편집 |
| `lib/ui/loadout_list_page.dart`, `loadout_editor_page.dart` | CREATE | 묶음 목록·편집 |
| `lib/ui/apply_loadout_page.dart` | CREATE | 비교와 7슬롯 쓰기 |
| `lib/ui/sign_in_page.dart` | CREATE | 이메일 OTP 로그인 |
| `lib/ui/design_gallery_page.dart` | CREATE | 디자인 컴포넌트 한눈에 보기 |
| `lib/ui/slots_page.dart` | UPDATE | `run_guard` 사용, 셸 안의 "원시 값" 화면이 됨 |
| `lib/main.dart` | UPDATE | Supabase 초기화(설정이 있을 때만), 셸 실행 |
| `supabase/migrations/0001_library.sql` | CREATE | 테이블·RLS |
| `supabase.example.json` | CREATE | 설정 예시 (실제 `supabase.json` 은 .gitignore) |
| `.gitignore` | UPDATE | `supabase.json` |
| `macos/Runner/*.entitlements` | UPDATE | `network.client` |
| `pubspec.yaml` | UPDATE | `supabase_flutter` |
| `test/**` | CREATE | 아래 Testing Strategy |
| `docs/prd.md` | UPDATE | 1단계 상태, 2단계 범위·결정 |

## NOT Building

- 카메라 슬롯·JPEG EXIF·OCR 가져오기 - 4단계
- RAW 미리보기 - 5단계
- Android 화면 대응 - 3단계 (화면은 넓은 창 기준, 좁은 창에서 깨지지 않을 정도만)
- 실시간 동기화(Realtime), 여러 사용자 공유, 충돌 수동 해결 - 본인 1인용. 최근 수정 우선
- 레시피 사진, 태그 검색 고급 기능 - 태그는 문자열 목록과 단순 필터만
- 밝은 테마 - 다이얼풍 어두운 테마 하나

---

## Step-by-Step Tasks

### 묶음 A: 1단계 보정

#### Task A1: 쓰기 순서 (TDD)
- **ACTION**: `FujiProp.writeOrder` 와 `FujiCamera._writeSlot` 순서 적용
- **IMPLEMENT**: `writeOrder = [D18E, D18F, D190, D191, D192, D193, D194, D195, D196, D197, D198, D199, D19C, D19A, D19B, D19D, D19E, D19F, D1A0, D1A1, D1A2, D1A3, D1A4, D1A5]`. `_writeSlot` 은 이름을 먼저 쓰고, 그다음 `writeOrder` 순서로 바뀐 속성만 쓴다
- **GOTCHA**: 지금은 `target.props` 의 키 순서(오름차순)로 쓴다. 카메라가 D19C 를 거부하는 원인이 된다
- **VALIDATE**: 가짜 전송이 받은 쓰기 순서에서 D199 → D19C → D19A 를 확인

#### Task A2: 7슬롯 일괄 쓰기 (TDD)
- **ACTION**: `FujiCamera.writeSlots(List<SlotSnapshot> targets, {required List<SlotSnapshot> current})`
- **IMPLEMENT**: `_keepingSelectedSlot` 한 번 안에서 슬롯마다 `_writeSlot`. 전체 시간과 왕복 횟수를 로그에 남기고 결과 목록 반환. 중간 실패는 그대로 던진다 (화면이 표를 비우고 다시 읽게 함)
- **VALIDATE**: 7슬롯 결과, 원래 슬롯 복귀, 바뀐 값만 쓰기

#### Task A3: 원자적 JSON 쓰기 공용화
- **ACTION**: `lib/util/atomic_json.dart` 의 `Future<File> writeJsonAtomically(File file, Object json)`, `SlotBackupStore.save` 가 사용
- **VALIDATE**: 기존 백업 시험 통과

### 묶음 B: 디자인 시스템

#### Task B1: 토큰과 테마
- **IMPLEMENT**: `AppColors` (바탕 #0F1012, 면 #17191C, 선 #2A2D31, 글자 #ECE9E4 / 보조 #9A9690, 강조 다이얼 주황 #F08A24, 경고 #E5484D, 성공 #3FB27F), `AppSpacing` (4·8·12·16·24·32), `AppRadius` (4·8·999), `AppType` (숫자는 `FontFeature.tabularFigures()`, 라벨은 대문자 작은 글씨 자간 0.8). `buildAppTheme()` 이 `ColorScheme.dark` 를 토큰으로 채운다
- **GOTCHA**: 글꼴 패키지(google_fonts)는 쓰지 않는다. 시스템 글꼴 + 고정폭 숫자
- **VALIDATE**: 강조색 대비 4.5:1 이상 (바탕 대비 글자, 강조색은 큰 숫자·선에만)

#### Task B2: DialScale (TDD, 위젯 시험)
- **IMPLEMENT**: `DialScale({required double value, required double min, max, step, required ValueChanged<double> onChanged, String Function(double)? format})`. 가운데 고정 바늘, 눈금이 좌우로 움직임. 드래그·클릭·스크롤·←→ 키로 `step` 단위 이동, 끝에서 멈춤. `Semantics(slider: true, value:, increasedValue:, decreasedValue:)`. 기본 값(0)에 작은 점
- **GOTCHA**: 값은 `step` 배수로 반올림해 부동소수 오차(0.30000000000000004)를 막는다
- **VALIDATE**: 드래그·키보드·범위 끝·반올림 위젯 시험

#### Task B3: KnobSelector, SlotBadge, ChangeRow (위젯 시험)
- **IMPLEMENT**: `KnobSelector<T>({required List<(T, String)> options, required T value, onChanged})` 가로 세그먼트, 선택 칸은 강조색 테두리, ←→ 키 이동. `SlotBadge(slot, {bool active})` 원형 C1–C7. `ChangeRow(label, before, after)` 값이 같으면 흐리게, 다르면 이후 값을 강조색으로
- **VALIDATE**: 선택 변경, 키보드 이동, 바뀐 행 강조

#### Task B4: 디자인 갤러리 화면
- **IMPLEMENT**: 위 컴포넌트를 모두 놓은 화면. 셸의 "디자인" 항목
- **VALIDATE**: 위젯 시험에서 렌더 오류 없음

### 묶음 C: 레시피 모델

#### Task C1: 필드 표와 Recipe (TDD)
- **IMPLEMENT**: `RecipeField` (id, 속성 코드, 이름, 종류 `choice|scale`, 선택지 또는 min/max/step). `Recipe` 는 불변이고 필드별 값이 `null` 이면 "카메라 값 유지". `id`(무작위 16진수 32자, `Random.secure`), `name`, `tags`, `updatedAt`, `deletedAt`. `toJson`/`fromJson`(패턴 매칭 검증, 범위 밖 값은 FormatException)
- **VALIDATE**: JSON 왕복, 잘못된 값 거부

#### Task C2: RecipeCodec (TDD)
- **IMPLEMENT**: `Recipe decodeSlot(SlotSnapshot)`: 표에 있는 값만 해석, 모르는 값(열거에 없음, 0x8000)은 `null`. `SlotSnapshot encodeRecipe(Recipe, {required SlotSnapshot base})`: base 의 속성을 복사하고 레시피 값이 있는 필드만 덮어쓴다. 조건부 규칙: 색온도는 WB=0x8007 일 때만, 흑백 시뮬레이션(Monochrome·Acros·Sepia 계열)이면 D19F 를 base 값으로 두고 D193/D194 는 0이 아닐 때만, 컬러 시뮬레이션이면 D193/D194 를 base 값으로 둔다. 이름은 레시피 이름(254자 한도)
- **GOTCHA**: 하이라이트 +1.5 → 15 처럼 ×10 은 `round()`. NR 은 표 변환이지 ×10 이 아니다
- **VALIDATE**: 필드별 왕복, 조건부 규칙, 모르는 값 보존

#### Task C3: RecipeDiff (TDD)
- **IMPLEMENT**: `List<FieldChange> diffRecipes(Recipe? current, Recipe target)` — 이름 포함, 사람이 읽는 값 문자열(`'+1.5'`, `'Classic Neg.'`)로 이전·이후. `target` 값이 null 인 필드는 바뀌지 않음
- **VALIDATE**: 같은 레시피는 빈 목록, 바뀐 필드만 나옴

### 묶음 D: 보관함 저장소

#### Task D1: Loadout 모델 (TDD)
- **IMPLEMENT**: `Loadout { id, name, List<String?> slots (길이 7), updatedAt, deletedAt }`, JSON 검증
- **VALIDATE**: 길이 7이 아니면 FormatException

#### Task D2: LibraryStore (TDD)
- **IMPLEMENT**: 디렉터리에 `recipes.json`, `loadouts.json`. `load()`, `recipes`/`loadouts` (삭제 표시 제외), `saveRecipe`, `deleteRecipe`(삭제 시각만 기록), `saveLoadout`, `deleteLoadout`, `applyRemote(...)`(동기화용). 저장할 때마다 `updatedAt = clock()`. `ChangeNotifier`. 묶음이 삭제된 레시피를 가리키면 그 칸은 비움으로 보인다
- **VALIDATE**: 저장·다시 불러오기, 삭제 표시, 깨진 파일은 FormatException

### 묶음 E: 화면

#### Task E1: run_guard 와 셸
- **IMPLEMENT**: `SlotsPage._run` 을 `runGuarded(log, label, action)` 으로 빼고 1단계 화면도 쓴다. `AppShell`: `NavigationRail` + 오른쪽 내용 + 하단 로그 패널(1단계 것을 옮김). 연결 버튼과 카메라 상태는 셸 상단에 하나만
- **VALIDATE**: 1단계 위젯 시험이 셸 안에서도 통과

#### Task E2: 레시피 목록·편집
- **IMPLEMENT**: 목록(이름, 필름 시뮬레이션, 태그, 새로 만들기). 편집: 필드 표 순서대로 `KnobSelector`/`DialScale`. 조건부 필드는 숨김(색온도는 WB=색온도일 때, 모노 WC/MG 는 흑백일 때, 컬러는 컬러 시뮬레이션일 때). "카메라 값 유지"(null) 로 되돌리는 버튼
- **VALIDATE**: 새 레시피 저장, 조건부 필드 표시, 값 변경 후 저장

#### Task E3: 묶음 목록·편집
- **IMPLEMENT**: 슬롯 7칸 각각에 레시피 고르기(비움 포함), 이름. 목록에서 "비교" 로 이동
- **VALIDATE**: 묶음 저장, 비운 칸 유지

#### Task E4: 비교와 7슬롯 쓰기
- **IMPLEMENT**: 진입 시 카메라 7슬롯을 읽고, 슬롯마다 `decodeSlot(current)` 와 묶음의 레시피를 `diffRecipes` 로 비교해 `ChangeRow` 목록. 비운 칸은 "그대로". "7슬롯 쓰기": 새로 읽기 → 백업 → 슬롯마다 `encodeRecipe(recipe, base: fresh)` → `writeSlots` → 결과(거부·불일치)와 전체 시간 표시, 10초 넘으면 경고색. 실패하면 비교를 비우고 다시 읽게 함
- **VALIDATE**: 가짜 카메라에서 바뀐 슬롯만 쓰임, 백업 1개 생성, 비운 칸은 쓰지 않음, 시간 표시

### 묶음 F: Supabase

#### Task F1: 스키마
- **IMPLEMENT**: `recipes`, `loadouts` 테이블: `id text primary key`, `user_id uuid not null default auth.uid() references auth.users`, `body jsonb not null`, `updated_at timestamptz not null`, `deleted_at timestamptz`. RLS: `user_id = auth.uid()` 인 행만 select/insert/update. 인덱스 `(user_id, updated_at)`
- **VALIDATE**: 사용자가 Supabase SQL 편집기에서 실행 (Manual Validation)

#### Task F2: 설정과 로그인
- **IMPLEMENT**: `supabase.json` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) 을 `--dart-define-from-file` 로 받음. 값이 없으면 동기화 메뉴를 "설정 없음" 으로 보이고 앱은 기기 저장만으로 동작. 로그인: 이메일 입력 → `signInWithOtp` → 6자리 코드 입력 → `verifyOTP`. macOS `network.client` 엔타이틀먼트
- **GOTCHA**: anon key 는 공개 키지만 저장소에는 넣지 않는다(`supabase.json` 은 .gitignore). service_role 키는 절대 앱에 넣지 않는다
- **VALIDATE**: 설정 없음 상태 위젯 시험, 실제 로그인은 수동

#### Task F3: 동기화 (TDD, 가짜 원격)
- **IMPLEMENT**: `RemoteLibrary` 인터페이스(`fetchSince(DateTime?)`, `upsert(rows)`) + Supabase 구현. `SyncService.sync()`: 마지막 동기화 이후 바뀐 로컬 행 올리기 → 원격에서 바뀐 행 내려받기 → id 별로 `updatedAt` 이 늦은 쪽 채택(삭제 표시 포함) → 마지막 동기화 시각 저장. 원격에서 온 `body` 는 `Recipe.fromJson`/`Loadout.fromJson` 으로 검증하고, 실패한 행은 건너뛰고 로그. 네트워크 오류는 로그만 남기고 기기 데이터는 그대로
- **VALIDATE**: 병합 규칙(로컬이 최신, 원격이 최신, 삭제), 잘못된 원격 행 건너뜀, 오프라인

---

## Testing Strategy

### Unit Tests

| Test | Input | Expected Output | Edge Case? |
|---|---|---|---|
| 쓰기 순서 | WB=색온도 레시피 | D199 → D19C → D19A → D19B | |
| 일괄 쓰기 | 7슬롯 중 2슬롯 변경 | 2슬롯만 속성 쓰기, 원래 슬롯 복귀 | |
| 코덱 왕복 | 필드별 값 | decode(encode(r)) == r | |
| 하이라이트 | +1.5 / -2 / 0x8000 | 15 / -20 / null | ✓ |
| NR | -4…+4 | 표 값, 표에 없는 값 → null | ✓ |
| 흑백 규칙 | Acros + 컬러 3 | D19F 는 base 값 유지 | ✓ |
| 모노 0 | Acros + WC 0 | D193 은 base 값 유지 | ✓ |
| 색온도 규칙 | WB=Auto + 색온도 5500 | D19C 는 base 값 유지 | ✓ |
| 모르는 열거 값 | D192=0x99 | 필름 시뮬레이션 null, 다시 쓰면 0x99 유지 | ✓ |
| diff | 같은 레시피 / 2필드 차이 | 빈 목록 / 2행 | |
| Recipe JSON | 범위 밖 하이라이트 9 | FormatException | ✓ |
| Loadout JSON | 슬롯 6칸 | FormatException | ✓ |
| LibraryStore | 저장 → 새 인스턴스로 불러오기 | 같음, 삭제 표시는 목록에서 빠짐 | |
| Sync 병합 | 로컬·원격 updatedAt 비교 | 늦은 쪽 | ✓ |
| Sync 잘못된 행 | body 깨짐 | 건너뛰고 로그 | ✓ |
| Sync 오프라인 | 원격이 예외 | 로컬 그대로, 로그 | ✓ |

### Widget Tests
- DialScale: 드래그, ←→, 끝에서 멈춤, step 반올림, Semantics 값
- KnobSelector: 탭·키보드 선택
- 레시피 편집: 조건부 필드 표시/숨김, 저장
- 비교·쓰기: 가짜 카메라 7슬롯에 묶음 적용, 백업 1개, 비운 칸 안 씀
- 설정 없는 동기화: "설정 없음" 표시, 앱 정상 동작
- 1단계 원시 값 화면 시험 유지

### Edge Cases Checklist
- [x] 빈 보관함, 빈 묶음 칸
- [x] 범위 끝 값, 부동소수 반올림
- [x] 깨진 로컬 파일·원격 행
- [x] 네트워크 실패
- [ ] 동시 수정 - 1인용, 최근 수정 우선으로 처리
- [ ] 로그인 거부·코드 만료 - 수동 확인

---

## Validation Commands

모두 `Project/recipe-slot-manager/` 에서 실행한다.

```bash
dart format --set-exit-if-changed lib test
```
```bash
flutter analyze
```
```bash
flutter test --coverage
```
EXPECT: 전부 통과, Skipped 0, 라인 커버리지 85% 이상 (Supabase 구현 파일 제외)
```bash
flutter build macos --debug --dart-define-from-file=supabase.example.json
```

### Manual Validation (사용자)
- [ ] supabase.com 에서 프로젝트 생성, SQL 편집기에서 `supabase/migrations/0001_library.sql` 실행
- [ ] Authentication → Providers → Email 이 켜져 있는지 확인 (기본값)
- [ ] `supabase.example.json` 을 `supabase.json` 으로 복사하고 URL·anon key 입력
- [ ] `flutter run -d macos --dart-define-from-file=supabase.json` → 이메일 코드 로그인 → 레시피 저장 → 동기화 → Supabase 표에 행이 생김
- [ ] 레시피 편집 화면에서 다이얼·노브 조작감 확인
- [ ] (카메라를 쓸 수 있을 때) 묶음 적용 → 카메라 메뉴에서 7슬롯 확인, 전체 시간 10초 이내

---

## Acceptance Criteria
- [ ] 묶음 A–F 완료, 묶음마다 커밋
- [ ] 위 검증 명령 통과
- [ ] 가짜 카메라로 "묶음 고르기 → 비교 → 7슬롯 쓰기" 흐름이 위젯 시험으로 확인됨
- [ ] Supabase 설정 없이도 앱이 동작함

## Completion Checklist
- [ ] 외부 JSON 은 패턴 매칭 검증 + FormatException
- [ ] 화면 작업은 `runGuarded`
- [ ] 범위·인코딩은 `recipe_fields.dart` 한 곳
- [ ] 색·간격은 토큰만 사용 (화면 코드에 색 값 직접 쓰지 않음)
- [ ] 비밀 값 없음 (`supabase.json` 은 .gitignore)

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| X-T5 값이 X100VI 기준 표와 다름 | M | M | 표가 한 파일에 있음. 모르는 값은 보존해 덮어쓰지 않음 |
| 실기기 시험 없이 묶음 쓰기를 실제로 쓰게 됨 | M | H | 쓰기 전 자동 백업 유지, 화면에 "실기기 미확인" 표시를 PRD 열린 질문이 닫힐 때까지 둠 |
| supabase_flutter 가 macOS 샌드박스에서 막힘 | L | M | `network.client` 엔타이틀먼트, 설정 없음 모드로 앱은 동작 |
| 범위가 커서 한 PR 이 커짐 | H | M | 묶음별 커밋, 필요하면 F 를 별도 PR 로 분리 |

## Notes
- **Confidence: 7/10.** Dart 로직과 화면은 시험으로 끝까지 확인된다. Supabase 연결과 실기기는 사용자가 확인해야 한다.
- PRD 의 "기기 SQLite 캐시" 를 JSON 파일 저장으로 바꾼다. 레코드가 수십 개 규모이고, 1단계의 원자적 JSON 저장을 그대로 쓸 수 있어 의존성이 하나 줄어든다.
- 디자인 시스템은 사용자 결정(2026-10-17)으로 2단계에 들어왔다.
