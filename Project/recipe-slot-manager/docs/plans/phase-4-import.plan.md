# Plan: 가져오기 (4단계)

## Summary
레시피를 손으로 입력하지 않고 세 경로로 보관함에 넣는다: 카메라 슬롯, 후지 JPEG 의 EXIF(MakerNote), 레시피가 적힌 이미지의 OCR(SNS 캡처, 레시피 사이트 스크린샷). 세 경로 모두 읽은 값만 채운 새 레시피를 편집 화면으로 열고, 사용자가 확인한 뒤 저장한다. 읽지 못한 값은 빈칸(카메라 값 유지)으로 둔다.

## User Story
As X-T5 사용자, I want 카메라 슬롯, 예전 사진, 웹·SNS 레시피 캡처에서 레시피를 바로 가져오기를, so that 값 20여 개를 손으로 옮겨 적지 않는다.

## Problem → Solution
레시피는 편집 화면에서 손으로만 만든다 → 레시피 목록의 "가져오기" 에서 출처를 고르면 읽은 값이 채워진 편집 화면이 열린다.

## Metadata
- **Complexity**: XL (새 하위 시스템 셋: EXIF 해석, 글자 해석, OCR 플랫폼 채널)
- **Source PRD**: `Project/recipe-slot-manager/docs/prd.md`
- **PRD Phase**: 4. 가져오기
- **Estimated Files**: 약 22개 (Dart 9, Swift 1, Kotlin 1, 설정 4, 시험 7)
- **커밋 단위**: 묶음 A–E 마다 하나 이상
- **사용자 결정 (2026-10-18)**: OCR 대상은 SNS 캡처와 레시피 사이트 스크린샷, EXIF 시험용 X-T5 원본 JPEG 는 사용자가 준다, OCR 은 macOS(Vision)·Android(ML Kit) 둘 다

---

## UX Design

### Before
```
[레시피 0개]                [+ 새 레시피]
```

### After
```
[레시피 0개]      [가져오기 ▾] [+ 새 레시피]
                    ├ 카메라 슬롯   → C1–C7 중 고르기
                    ├ 사진 (EXIF)   → JPEG 고르기
                    └ 이미지 글자   → 이미지 고르기 → 글자 인식
                          ↓
        편집 화면: 읽은 값만 채워짐, 나머지는 빈칸
        위쪽 안내: "EXIF 에서 14개 항목을 읽었다. 빈칸은 카메라 값을 유지한다"
                          ↓
                        [저장]
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| 레시피 목록 | 새 레시피만 | 가져오기 메뉴(출처 셋) | 카메라 미연결이면 "카메라 슬롯" 은 연결부터 하라고 알린다 |
| 편집 화면 | 빈 값으로 시작 | 가져온 값으로 시작, 출처와 읽은 항목 수 안내 | 저장 전까지 보관함에 들어가지 않는다 |
| 파일 고르기 | - | 시스템 파일 선택 창 (JPEG / 이미지) | macOS 는 사용자가 고른 파일 읽기 권한 필요 |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `lib/recipe/recipe_fields.dart` | all | 필드 id·선택지 코드·범위. 가져온 값은 모두 이 표의 `accepts` 를 통과해야 한다 |
| P0 | `lib/recipe/recipe_codec.dart` | 8-20 | `decodeSlot`: 카메라 슬롯 → 레시피 값 |
| P0 | `lib/ui/recipe_editor_page.dart` | 13-40 | 편집 화면 진입, 값이 null 이면 빈칸 |
| P0 | `lib/ui/recipe_list_page.dart` | all | 가져오기 메뉴를 놓을 곳 |
| P1 | `lib/camera/ptp_channel.dart`, `macos/Runner/PtpChannel.swift`, `android/.../PtpChannel.kt` | all | 플랫폼 채널 모양(오류 코드, 작업 스레드) |
| P1 | `lib/camera/camera_session.dart` | all | `run` 으로 카메라 작업, 오류 로그 |
| P2 | `test/support/test_app.dart` | all | 화면 시험 준비 |

## External Documentation

| Topic | Source | Key Takeaway |
|---|---|---|
| 후지 MakerNote | ExifTool FujiFilm 태그 표 | MakerNote 는 `FUJIFILM` 8바이트 + u32 IFD 위치(보통 12). 항상 리틀 엔디언, 위치는 MakerNote 시작 기준 |
| 파일 고르기 | pub.dev `file_selector` 1.1.0 (Dart ^3.9, Flutter ≥3.35) | `openFile(acceptedTypeGroups:)` → `XFile`. macOS 는 `com.apple.security.files.user-selected.read-only` 엔타이틀먼트 |
| macOS OCR | Apple Vision `VNRecognizeTextRequest` | `.accurate`, `recognitionLanguages = ["ko-KR", "en-US"]`, 결과는 줄 단위 `topCandidates(1)` |
| Android OCR | ML Kit `com.google.mlkit:text-recognition-korean:16.0.1` | `KoreanTextRecognizerOptions`, 라틴 글자도 함께 읽는다. 모델이 APK 에 들어가 크기가 늘어난다 |

### 후지 MakerNote → 레시피 필드 (ExifTool 표 기준, 표본 JPEG 로 확인할 것)

| 태그 | 이름 | 값 → 레시피 |
|---|---|---|
| 0x1401 | FilmMode | 0x000 Provia, 0x200·0x400 Velvia, 0x120 Astia, 0x500 PRO Neg. Std, 0x501 PRO Neg. Hi, 0x600 Classic Chrome, 0x700 Eterna, 0x800 Classic Neg., 0x900 Eterna Bleach Bypass, 0xA00 Nostalgic Neg., 0xB00 Reala Ace |
| 0x1003 | Saturation | 흑백: 0x300 Monochrome, 0x301 +R, 0x302 +Ye, 0x303 +G, 0x310 Sepia, 0x500 Acros, 0x501 +R, 0x502 +Ye, 0x503 +G. 컬러일 때 컬러 값: 0x000 0, 0x080 +1, 0x100 +2, 0x0C0 +3, 0x0E0 +4, 0x180 −1, 0x400 −2, 0x4C0 −3, 0x4E0 −4 |
| 0x1001 | Sharpness | 0x00 −4, 0x01 −3, 0x02 −2, 0x82 −1, 0x03 0, 0x84 +1, 0x04 +2, 0x05 +3, 0x06 +4 |
| 0x1041 / 0x1040 | HighlightTone / ShadowTone (int32s) | 레시피 값 = −원시 값 / 16 (−64 → +4, 8 → −0.5) |
| 0x100E | NoiseReduction | 0x000 0, 0x180 +1, 0x100 +2, 0x1C0 +3, 0x1E0 +4, 0x280 −1, 0x200 −2, 0x2C0 −3, 0x2E0 −4 |
| 0x100F | Clarity (int32s) | 원시 값 / 1000 |
| 0x1047 + 0x104C | GrainEffectRoughness + Size | 0 → 끔. (32,16) 약·소, (64,16) 강·소, (32,32) 약·대, (64,32) 강·대 |
| 0x1048 / 0x104E | ColorChromeEffect / FXBlue | 0 끔, 32 약, 64 강 |
| 0x1002 | WhiteBalance | 0x000 오토, 0x002 주변광 우선, 0x100 맑음, 0x200 그늘, 0x300·0x301·0x302 형광등 1·2·3, 0x400 백열등, 0x600 수중, 0xFF0 색온도. 0x001(흰색 우선)은 필드 표에 없어 빈칸 |
| 0x1005 | ColorTemperature | 그대로 (WB 가 색온도일 때만) |
| 0x100A | WhiteBalanceFineTune (int32s ×2) | R, B. 원시 값 / 20 으로 추정 — 표본으로 확인 |
| 0x1403 | DevelopmentDynamicRange | 100 / 200 / 400 |
| 0x1049 / 0x104B | BWAdjustment / BWMagentaGreen (int8s) | 모노 WC / MG. 배율은 표본으로 확인 |

스무스 스킨은 해당 태그를 찾지 못했다. 빈칸으로 두고 표본에서 찾으면 더한다.

---

## Patterns to Mirror

### NAMING_CONVENTION
```dart
// SOURCE: lib/recipe/recipe_codec.dart:8-10
/// 슬롯 속성을 레시피 값으로 바꾼다. 해석할 수 없는 값과, 지금 필름 시뮬레이션·WB 에서
/// 의미 없는 필드는 빠진다 (빠진 필드는 "카메라 값 유지").
Map<String, double> decodeSlot(SlotSnapshot slot) {
```
→ `Map<String, double> decodeFujiMakerNote(...)`, `Map<String, double> parseRecipeText(...)`. 결과 형태는 셋 다 `decodeSlot` 과 같은 `Map<String, double>`.

### ERROR_HANDLING
```dart
// SOURCE: lib/camera/ptp_channel.dart:8-19
Future<T> guardPtpChannel<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on PlatformException catch (e) {
    throw PtpTransportException(e.message ?? e.code);
```
→ 가져오기 실패는 `ImportException(message)` 하나로 올리고 화면은 스낵바로 보인다. JPEG 이 아니거나 후지 MakerNote 가 없으면 `ImportException`, 일부 태그를 못 읽은 것은 실패가 아니라 빈칸이다.

### TEST_STRUCTURE
```dart
// SOURCE: test/camera/android_ptp_transport_test.dart (채널 가짜 처리기)
messenger.setMockMethodCallHandler(channel, (call) async { ... });
```
EXIF 시험은 시험 안에서 최소 JPEG(APP1 Exif + 후지 MakerNote)를 바이트로 만든다.

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `lib/import/recipe_import.dart` | CREATE | `ImportedRecipe(name, values, source, readCount)`, `ImportException` |
| `lib/import/jpeg_exif.dart` | CREATE | JPEG → APP1 → TIFF → Exif IFD → MakerNote 바이트 |
| `lib/import/fuji_makernote.dart` | CREATE | MakerNote IFD 읽기, 위 표로 레시피 값 |
| `lib/import/recipe_text_parser.dart` | CREATE | OCR 글자 줄 → 레시피 값 (영어·한국어 이름) |
| `lib/import/text_recognizer.dart` | CREATE | OCR 채널 `recipe_slot_manager/ocr`, `recognizeText(bytes)` → 줄 목록 |
| `lib/ui/import_menu.dart` | CREATE | 가져오기 메뉴, 세 출처 흐름, 편집 화면 열기 |
| `lib/ui/recipe_list_page.dart` | UPDATE | 가져오기 메뉴, 세션 받기 |
| `lib/ui/recipe_editor_page.dart` | UPDATE | 가져온 출처·항목 수 안내 한 줄 |
| `lib/ui/app_shell.dart` | UPDATE | 레시피 목록에 세션 넘기기 |
| `macos/Runner/OcrChannel.swift`, `MainFlutterWindow.swift` | CREATE / UPDATE | Vision 글자 인식 |
| `macos/Runner/*.entitlements` | UPDATE | 사용자가 고른 파일 읽기 |
| `android/.../OcrChannel.kt`, `MainActivity.kt`, `app/build.gradle.kts` | CREATE / UPDATE | ML Kit 한국어 글자 인식 |
| `pubspec.yaml` | UPDATE | `file_selector` |
| `tool/make_exif_fixture.dart` | CREATE | 표본 JPEG 에서 레시피 태그만 남긴 작은 시험용 JPEG 를 만든다 |
| `test/import/*_test.dart`, `test/fixtures/exif/*.jpg` | CREATE | 해석기 시험, 개인정보를 뺀 표본 |
| `test/ui/import_flow_test.dart` | CREATE | 메뉴 → 편집 화면 흐름 |
| `docs/prd.md` | UPDATE | 3단계 complete, 4단계 in-progress, EXIF 열린 질문 결과 |

## NOT Building

- RAF(RAW) EXIF 읽기 - JPEG 만
- 사진 여러 장 한 번에 가져오기 - 한 장씩
- OCR 결과 줄을 화면에서 직접 고치는 편집기 - 편집 화면에서 값을 고친다
- 다른 사람 레시피 사이트 크롤링·URL 가져오기 - 이미지만
- 같은 레시피가 이미 있는지 찾기 - 나중 작업
- GPS 장소 기록 - 따로 스펙 (사진 EXIF 의 위치는 읽지 않는다)

---

## Step-by-Step Tasks

### 묶음 A: 공통 흐름

#### Task A1: 가져온 레시피 모델과 편집 화면 진입 (TDD)
- **IMPLEMENT**: `ImportedRecipe { name, values, source }`. `values` 는 `fieldById[id]!.accepts(v)` 를 통과한 것만 남기고, 의미 없는 필드(흑백인데 컬러 등)는 `isApplicable` 로 뺀다. 편집 화면은 `importNote`(예: "EXIF 에서 14개 항목을 읽었다. 빈칸은 카메라 값을 유지한다")를 받아 위에 한 줄로 보인다
- **VALIDATE**: 범위 밖 값·없는 필드 id 가 걸러지는 단위 시험, 편집 화면 안내 위젯 시험

#### Task A2: 가져오기 메뉴
- **IMPLEMENT**: 레시피 목록 머리에 `PopupMenuButton`(카메라 슬롯 / 사진 EXIF / 이미지 글자). 실패는 `ImportException.message` 스낵바
- **GOTCHA**: 휴대폰 폭에서 버튼 둘이 머리줄에 들어가야 한다. 3단계 넘침 시험에 이 화면을 이미 넣었으니 그대로 통과해야 한다

### 묶음 B: 카메라 슬롯

#### Task B1: 슬롯 고르기 (TDD)
- **IMPLEMENT**: 연결 안 됨 → 스낵바 "카메라를 먼저 연결할 것". 연결됨 → `session.run('7슬롯 읽기', camera.readAllSlots)` → C1–C7 이름 목록 대화상자 → `decodeSlot(slot)`, 이름은 슬롯 이름
- **VALIDATE**: 가짜 전송으로 C3 를 고르면 편집 화면에 C3 이름과 값

### 묶음 C: EXIF

#### Task C1: JPEG → MakerNote (TDD)
- **IMPLEMENT**: SOI 확인 → APP1 `Exif\0\0` 찾기 → TIFF 머리(II/MM) → IFD0 의 0x8769 → Exif IFD 의 0x927C(MakerNote) 바이트
- **GOTCHA**: 파일 전체를 읽지 않는다. `XFile.openRead(0, 256 KiB)` 로 앞부분만. APP1 은 64 KiB 안에 있다
- **VALIDATE**: 시험에서 만든 최소 JPEG, JPEG 아님·Exif 없음·MakerNote 없음 → `ImportException`

#### Task C2: 후지 MakerNote → 레시피 값 (TDD)
- **IMPLEMENT**: 위 표. 흑백 시뮬레이션은 FilmMode 대신 Saturation 으로 정하고, 그때는 컬러를 넣지 않는다. 표에 없는 원시 값은 빈칸
- **VALIDATE**: 태그별 시험(원시 값 → 레시피 값), 흑백·컬러 갈림

#### Task C3: 표본으로 확인 (사용자 JPEG 필요)
- **ACTION**: 사용자가 `samples/`(gitignore)에 X-T5 원본 JPEG 1–3장과 각 사진의 레시피 값을 둔다
- **IMPLEMENT**: `tool/make_exif_fixture.dart` 가 표본에서 레시피 태그만 남긴 작은 JPEG 을 `test/fixtures/exif/` 에 만든다(GPS·일련번호·썸네일 제외). 이 표본으로 표의 "확인할 것" 항목(WB 시프트 배율, 모노 WC·MG, 스무스 스킨)을 정한다
- **VALIDATE**: 표본마다 해석 결과가 사용자가 적은 값과 같다

#### Task C4: 파일 고르기
- **IMPLEMENT**: `file_selector` 추가, JPEG 형식 그룹(`jpg`, `jpeg`, MIME `image/jpeg`), macOS 엔타이틀먼트 두 파일에 `files.user-selected.read-only`
- **VALIDATE**: macOS·APK 빌드

### 묶음 D: OCR

#### Task D1: 글자 → 레시피 값 (TDD)
- **IMPLEMENT**: 줄마다 "이름 구분자 값" 을 찾는다(구분자 `:`, `-`, `：`, 공백). 이름은 필드마다 영어·한국어 별칭 표(예: `Highlight`·`Highlights`·`하이라이트`, `High ISO NR`·`Noise Reduction`·`노이즈 리덕션`·`고감도 NR`). 값은 필드 종류별로 읽는다
  - 선택지: 이름 별칭(`Classic Negative`·`Classic Neg.`·`클래식 네거티브`, `Weak, Small`·`약, 소`)
  - 눈금: 부호 붙은 숫자(`+1.5`, `-2`, `0`, `+½` 는 0.5)
  - WB: 모드 이름 또는 `5500K`, 같은 줄이나 다음 줄의 `+2 Red & -4 Blue`·`R+2 B-4`·`레드 +2 블루 -4`
  - 다이내믹 레인지: `DR400`, `DR-Auto` 는 빈칸
  - 모노: `Monochromatic Color: WC +2 MG -1`
  - ISO, 노출 보정 같은 레시피 밖 항목은 무시
- **GOTCHA**: OCR 은 `0`/`O`, `1`/`l`, `−`(유니코드 마이너스)를 섞는다. 숫자 자리에서만 바꾼다
- **VALIDATE**: Fuji X Weekly 형식 영어 예문, 한국어 SNS 예문, 줄이 섞이고 오타 있는 예문. 사용자가 캡처를 주면 OCR 결과 글자를 시험 예문으로 더한다

#### Task D2: OCR 채널
- **IMPLEMENT**: Dart `recognizeText(Uint8List image)` → `List<String>` 줄. 채널 `recipe_slot_manager/ocr`, 메서드 `recognize`
  - macOS `OcrChannel.swift`: `CGImageSource` → `VNImageRequestHandler` → `VNRecognizeTextRequest(.accurate, ["ko-KR","en-US"])`, 백그라운드 큐, 결과는 메인
  - Android `OcrChannel.kt`: `BitmapFactory.decodeByteArray` → `InputImage.fromBitmap` → `TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())`, 줄은 `textBlocks.flatMap { it.lines }`
- **GOTCHA**: 큰 스크린샷은 채널로 보내기 전에 줄이지 않는다(글자 인식 정확도). 몇 MB 는 채널로 문제없다
- **VALIDATE**: Dart 쪽 채널 가짜 처리기 시험, 두 플랫폼 빌드, macOS 앱에서 실제 캡처 1장으로 수동 확인

### 묶음 E: 확인과 문서
- 전체 시험·분석·형식·macOS·APK 빌드
- 수동: macOS 에서 세 경로 각각 1개씩 가져오기(카메라 슬롯은 실기기 없으므로 가짜 불가 → 미확인으로 기록)
- PRD: 3단계 complete(실기기 미확인), 4단계 상태, EXIF 열린 질문에 표본 결과

---

## Testing Strategy

| Test | Input | Expected | Edge? |
|---|---|---|---|
| 걸러내기 | 범위 밖 하이라이트 9, 없는 id | 둘 다 빠짐 | ✓ |
| 슬롯 가져오기 | 가짜 카메라 C3 | C3 이름·값 | |
| 미연결 | 연결 전 카메라 슬롯 | 안내 스낵바 | ✓ |
| JPEG 아님 | PNG 바이트 | ImportException | ✓ |
| MakerNote 없음 | Exif 만 있는 JPEG | ImportException | ✓ |
| 빅 엔디언 TIFF | MM 머리 | 같은 결과 | ✓ |
| 태그 표 | 각 원시 값 | 표의 레시피 값, 표 밖은 빈칸 | ✓ |
| 흑백 | Saturation 0x501 | Acros + R, 컬러 없음 | ✓ |
| 영어 예문 | Fuji X Weekly 형식 | 필드 전부 | |
| 한국어 예문 | SNS 형식 | 필드 전부 | |
| OCR 오타 | `O`, `−`, 섞인 줄 | 숫자 바로잡음 | ✓ |
| 표본 JPEG | 사용자 표본 | 사용자가 적은 값 | |

---

## Validation Commands

```bash
cd Project/recipe-slot-manager
flutter analyze
flutter test
dart format --set-exit-if-changed lib test tool
flutter build macos --debug --dart-define-from-file=supabase.example.json
flutter build apk --debug --dart-define-from-file=supabase.example.json
```

## Acceptance Criteria
- [ ] 세 경로 각각 레시피 1개가 편집 화면으로 들어오고 저장된다
- [ ] 읽지 못한 값은 빈칸, 범위 밖 값은 들어오지 않는다
- [ ] 표본 JPEG 해석이 사용자가 적은 값과 같다
- [ ] 시험 표본에 GPS·일련번호가 없다
- [ ] 검증 명령 전부 통과

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| ExifTool 표와 X-T5 실제 값이 다름 | 중 | 중 | 표본 JPEG 로 확인 뒤 표 수정 |
| SNS 레시피 형식이 제각각 | 높음 | 중 | 읽은 것만 채우고 편집 화면에서 확인. 실제 캡처를 예문으로 쌓는다 |
| ML Kit 한국어 모델로 APK 가 커짐 | 확실 | 낮음 | 본인용 앱이라 받아들인다 |
| 표본 사진의 개인정보가 저장소에 들어감 | 중 | 높음 | 원본은 gitignore, 시험 표본은 도구로 레시피 태그만 남긴다 |
| 카메라 슬롯 경로는 실기기 미확인 | 확실 | 중 | 가짜 전송 시험, 실기기 확인은 열린 질문으로 둔다 |

## Notes
- EXIF 해석은 패키지를 쓰지 않고 직접 쓴다. 필요한 것은 IFD 세 번 따라가기와 후지 MakerNote 하나이고, 일반 EXIF 패키지는 후지 MakerNote 의 레시피 태그를 다루지 않는다
- OCR 채널은 PTP 채널처럼 Dart 가 같은 메서드 이름 하나로 두 플랫폼을 부른다

## 구현 중 바뀐 점
- 순서: 메뉴가 두 해석기를 부르므로 D1(글자 해석)·C1·C2(EXIF 해석)를 먼저 하고 메뉴(A2·B1·C4)를 붙였다
- 레시피 목록 머리줄: 가져오기 버튼이 더해져 360 dp·글꼴 1.6배에서 91px 넘쳤다. 버튼 묶음을 `Wrap` 으로 바꿔 모자라면 다음 줄로 내린다
- macOS Vision 설정은 한국어·영어가 섞인 글을 그린 이미지로 확인했고, 그 결과 줄(`소/`, `&-4` 처럼 붙거나 떨어진 구분자)을 해석기 시험 예문으로 더했다
- Task C3(표본 JPEG)과 `tool/make_exif_fixture.dart` 는 사용자 표본을 받은 뒤 한다. 그전까지 EXIF 표는 ExifTool 기준이며 X-T5 미확인이다
- 리뷰 반영: 다른 카메라 작업 중에는 슬롯 가져오기를 막는다, Exif IFD 위치 값이 하나가 아니면 깨진 파일로 본다, OCR 은 긴 변을 4096 px 이하로 줄여 읽는다(Android 는 작업 스레드에서), 가져오기 버튼 높이 48, 제목 줄 낱말보다 "이름: 값" 줄을 먼저 쓴다
- 셸 탭 이름 "원시 값" → "카메라 슬롯". 그 화면은 카메라에 들어 있는 C1–C7 을 직접 읽고 쓰는 곳이라, 보관함의 레시피·묶음과 구별되는 이름으로 바꿨다. 가져오기 메뉴의 "카메라 슬롯" 과 같은 대상을 가리킨다
