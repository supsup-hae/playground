# Plan: 촬영 정보 읽기 (사진 기록 1단계)

## Summary
JPEG 앞부분에서 사진 기록에 필요한 정보(촬영 시각과 시간대, GPS 좌표, 기종, 촬영 번호, 필름 시뮬레이션을 포함한 레시피 값)를 한 번에 꺼내는 `readPhotoInfo` 를 만든다. 지금 EXIF 해석기는 RATIONAL 값의 크기를 몰라 GPS 좌표 위치를 잘못 계산하므로 함께 고친다. 화면 변경은 없다.

## User Story
As X-T5 사용자, I want 사진 파일 하나에서 언제·어디서·어떤 시뮬레이션으로 찍었는지를 읽기를, so that 2단계 이후의 색인·지도·필터가 이 정보로 동작한다.

## Problem → Solution
`readMakerNote` 는 MakerNote 만 꺼내고, `readIfd` 는 RATIONAL(5)·SRATIONAL(10)을 1바이트로 계산한다 → EXIF 를 한 번 해석해 IFD0·Exif·GPS IFD 를 함께 돌려주는 함수를 두고, 그 위에 `readPhotoInfo` 를 만든다.

## Metadata
- **Complexity**: Small–Medium (순수 Dart, 새 파일 2개, 수정 2개, 시험·도구)
- **Source PRD**: `Project/recipe-slot-manager/docs/photo-log.prd.md`
- **PRD Phase**: 1. 촬영 정보 읽기
- **Estimated Files**: 9개 (Dart 2, 시험 지원 1, 시험 2, 도구 1, 시험 자료 1, 문서 2)
- **커밋 단위**: A(EXIF 해석기), B(사진 정보), C(실제 표본 시험 자료)

---

## 표본에서 확인한 것 (XApp 으로 받은 X-T5 JPEG 2장, 2026-10-11)

| 항목 | 위치 | 값 |
|---|---|---|
| 기종 | IFD0 `0x0110` | `X-T5` |
| 촬영 시각 | Exif `0x9003` DateTimeOriginal | `2026:10:11 15:26:10`, `15:26:17` |
| 시간대 | Exif `0x9011` OffsetTimeOriginal | `+09:00` |
| 처리 시각 | IFD0 `0x0132` DateTime | `15:36:13` — 촬영 시각이 아니다. 쓰지 않는다 |
| GPS | IFD0 `0x8825` → GPS IFD | 항목 12개, 값은 모두 0. 좌표 `0/0` |
| 촬영 번호 | MakerNote `0x1438` | `1422`, `1423` (연달아 찍은 두 장) |
| 필름 시뮬레이션 | MakerNote `0x1401` | `0x700` → Eterna |
| 없음 | Exif `0x9291` SubSecTimeOriginal, `0xA420` ImageUniqueID | 판별 키로 쓸 수 없다 |
| 개인 정보 | Exif `0xA431` BodySerialNumber·`0xA435` LensSerialNumber, MakerNote `0x0010` InternalSerialNumber, IFD1 썸네일 | 시험 자료에서 지운다 |

**판별 키**: `기종|촬영 시각(벽시계)시간대|촬영 번호` 예: `X-T5|2026-10-11T15:26:10+09:00|1422`. 촬영 번호는 카메라 하나 안에서 이어지는 값이라 같은 초에 찍은 연사도 구분한다. 세 값 중 하나라도 없으면 키는 null 이고, 2단계가 파일 경로로 대신한다.

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `lib/import/jpeg_exif.dart` | all | 고칠 파일. `readIfd` 값 위치 계산, APP1 찾기 |
| P0 | `test/support/exif_builder.dart` | all | 가짜 JPEG 를 만드는 방법. 확장한다 |
| P1 | `lib/import/fuji_makernote.dart` | 8–24, 114–151 | `readFujiTags`, `decodeFujiRecipe` 재사용 |
| P1 | `test/import/fuji_exif_test.dart` | all | 기존 시험은 바꾸지 않고 통과해야 한다 |
| P2 | `lib/import/recipe_import.dart` | 15–24 | `ImportException` |

## External Documentation

| Topic | Source | Key Takeaway |
|---|---|---|
| GPS IFD | EXIF 2.32 §4.6.6 | 위도·경도는 RATIONAL 3개(도, 분, 초), 방향은 ASCII 2바이트 `N`/`S`, `E`/`W` |
| OffsetTimeOriginal | EXIF 2.31 | ASCII 7바이트 `±HH:MM` |
| Fuji ImageCount | ExifTool FujiFilm 표 `0x1438` | ExifTool 은 `값 & 0x7FFF` 로 읽는다 |

---

## Patterns to Mirror

### ERROR_HANDLING
// SOURCE: lib/import/jpeg_exif.dart:10, 57-59
```dart
const _broken = ImportException('파일이 잘렸거나 EXIF 정보가 깨졌다');
if (jpeg.length < 4 || jpeg[0] != 0xFF || jpeg[1] != 0xD8) {
  throw const ImportException('JPEG 파일이 아니다');
}
```

### RECORD_TYPES
// SOURCE: lib/import/jpeg_exif.dart:5, lib/import/file_pick.dart:7
```dart
typedef IfdEntry = ({int type, int count, int offset});
typedef PickedFile = ({String name, Uint8List bytes});
```

### NULL_AWARE_MAP
// SOURCE: lib/import/fuji_makernote.dart:131-150
```dart
'sharpness': ?lookup(_sharpness, tag(0x1001)),
```

### TEST_STRUCTURE
// SOURCE: test/import/fuji_exif_test.dart:32-48
```dart
group('readMakerNote', () {
  test('JPEG 이 아니면 ImportException', () {
    expect(() => readMakerNote(...), throwsA(isA<ImportException>()));
  });
```

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `lib/import/jpeg_exif.dart` | UPDATE | RATIONAL 크기, `readExif`(IFD0·Exif·GPS), `ifdRationals`, `ifdString`. `readMakerNote` 는 `readExif` 위에서 같은 동작 |
| `lib/photo/photo_info.dart` | CREATE | `PhotoInfo`, `readPhotoInfo`, 판별 키 |
| `test/support/exif_builder.dart` | UPDATE | ASCII·RATIONAL 값, IFD0·Exif·GPS 태그 인자 |
| `test/import/jpeg_exif_test.dart` | CREATE | RATIONAL 값 위치, 문자열 |
| `test/photo/photo_info_test.dart` | CREATE | 가짜 EXIF 와 실제 표본 자료로 `readPhotoInfo` |
| `tool/make_exif_fixture.dart` | CREATE | `samples/` 의 JPEG 에서 APP1 만 남기고 일련번호·썸네일을 지운 시험 자료를 만든다 |
| `test/fixtures/x_t5_eterna.jpg` | CREATE | 위 도구의 결과 (SOI + APP1 + EOI, 약 64 KiB) |
| `docs/unverified.md` | UPDATE | "사진 기록" 절: 위치 동기화를 켠 사진의 GPS |
| `docs/photo-log.prd.md` | UPDATE | 1단계 상태와 계획 연결 |

## NOT Building

- 폴더 탐색, 색인 저장 (2단계)
- 주소 변환 (3단계)
- HEIC·RAF 의 EXIF — XApp 과 Mac 폴더의 대상은 JPEG 다
- GPS 고도·방향·시각(GPSTimeStamp) — 찾기에 쓰지 않는다
- 시간대가 없는 사진의 시간대 추정

---

## Step-by-Step Tasks

### Task A1: RATIONAL 값 위치 (`jpeg_exif.dart`)
- **ACTION**: `_typeSizes` 에 `5: 8, 10: 8` 을 더한다
- **IMPLEMENT**: `ifdRationals(view, entry, endian) → List<double?>` — 분모가 0 이면 그 값은 null. 형식 10 은 부호 있는 int32 두 개. `ifdString(bytes, entry) → String` — 첫 NUL 앞까지, 앞뒤 공백 제거
- **GOTCHA**: 지금 `readIfd` 는 RATIONAL 3개(24바이트)를 3바이트로 보고 항목 안의 값 자리를 위치로 쓴다. 고친 뒤에는 항목의 u32 를 위치로 읽어야 한다. 기존 MakerNote 시험이 계속 통과해야 한다
- **VALIDATE**: `jpeg_exif_test.dart` — RATIONAL 3개 항목의 위치가 값 영역을 가리키고 `[35, 39, 31.2]` 로 읽힌다. `0/0` 은 null

### Task A2: `readExif` (`jpeg_exif.dart`)
- **ACTION**: APP1 찾기와 TIFF 머리 해석을 `readExif(Uint8List jpeg)` 로 꺼낸다
- **IMPLEMENT**: `typedef Exif = ({Uint8List tiff, ByteData view, Endian endian, Map<int, IfdEntry> ifd0, Map<int, IfdEntry>? exif, Map<int, IfdEntry>? gps});`. Exif·GPS 위치 태그는 값이 정확히 1개여야 하고(아니면 `_broken`), 없으면 null. `readMakerNote` 는 `readExif` 를 불러 지금과 같은 오류 문구로 동작한다
- **MIRROR**: ERROR_HANDLING, RECORD_TYPES
- **VALIDATE**: `fuji_exif_test.dart` 그대로 통과, GPS 위치 태그 값이 2개면 깨진 파일

### Task A3: 시험용 EXIF 만들기 (`exif_builder.dart`)
- **ACTION**: `tiffAscii = 2`, `tiffRational = 5` 를 더하고 `jpegWithExif` 에 `ifd0Tags`, `exifTags`, `gpsTags` 인자를 더한다
- **IMPLEMENT**: RATIONAL 값은 `[분자, 분모, ...]` 로 받고 개수는 절반. ASCII 는 `asciiValue('N')` 처럼 끝에 NUL 을 붙인 코드 목록. IFD 의 위치는 앞 IFD 의 전체 길이(머리 + 값 영역)로 정한다 — 값 영역 길이는 위치와 무관하므로 한 번 만들어 길이를 잰 뒤 위치를 넣어 다시 만든다
- **GOTCHA**: 기존 호출(`jpegWithExif(makerNote: ...)`)의 결과 바이트가 바뀌어도 되지만 기존 시험은 그대로 통과해야 한다
- **VALIDATE**: 전체 `flutter test test/import`

### Task B1: `PhotoInfo` (`lib/photo/photo_info.dart`)
- **IMPLEMENT**:
  ```dart
  typedef GeoPoint = ({double latitude, double longitude});

  final class PhotoInfo {
    final DateTime? shotAt;        // 벽시계 시각. DateTime.utc 로 담고 시간대는 utcOffset
    final Duration? utcOffset;
    final GeoPoint? location;
    final String? model;
    final int? imageCount;
    final Map<String, double> recipe;  // decodeFujiRecipe 결과, 후지가 아니면 빈 맵
    String? get key;               // 기종|시각+시간대|촬영 번호, 하나라도 없으면 null
  }

  PhotoInfo readPhotoInfo(Uint8List jpegHead);
  ```
- **GPS 규칙**: 방향 문자가 `N`/`S`·`E`/`W` 가 아니거나, 값이 3개가 아니거나, null 이 있으면 위치 없음. 도 + 분/60 + 초/3600, `S`·`W` 는 음수. 위도 ±90·경도 ±180 밖이면 위치 없음. 위도·경도가 둘 다 0 이면 위치 없음(표본의 빈 값)
- **시각 규칙**: `YYYY:MM:DD HH:MM:SS` 형식이 아니거나 월·일이 0 이면 null. 시간대는 `0x9011` 이 `±HH:MM` 일 때만
- **후지 규칙**: MakerNote 가 없거나 후지가 아니면(`ImportException`) 레시피는 빈 맵, 촬영 번호 null. 촬영 번호는 `0x1438 & 0x7FFF`(ExifTool 기준, 표본 값 1422·1423 은 영향 없음)
- **오류**: JPEG 이 아니거나 EXIF 가 깨졌으면 `ImportException` 을 그대로 던진다 (2단계가 그 사진을 건너뛰고 로그에 남긴다)
- **VALIDATE**: B2 시험

### Task B2: 사진 정보 시험 (`test/photo/photo_info_test.dart`)
- 아래 Testing Strategy 의 표 전부

### Task C1: 실제 표본 시험 자료 (`tool/make_exif_fixture.dart`)
- **ACTION**: `dart run tool/make_exif_fixture.dart samples/<파일>.jpg test/fixtures/x_t5_eterna.jpg`
- **IMPLEMENT**: SOI + 원본 APP1 + EOI. APP1 안에서 BodySerialNumber(`0xA431`)·LensSerialNumber(`0xA435`)·InternalSerialNumber(MakerNote `0x0010`) 값 바이트와 IFD1 썸네일 바이트(`0x0201` 위치부터 `0x0202` 길이)를 0 으로 채운다. GPS 에 값이 있으면 실패한다(위치가 든 사진은 시험 자료로 만들지 않는다)
- **GOTCHA**: 바이트 길이와 위치는 그대로 둔다(IFD 위치가 바뀌지 않게). `samples/` 는 커밋하지 않는다. 표본은 사용자가 대화에 올린 2장을 `samples/` 에 복사해 쓴다
- **VALIDATE**: 결과 파일에서 `6BA08168` 문자열과 썸네일 SOI(`FF D8`, 파일 머리 제외)가 없다. `readPhotoInfo` 가 Eterna·위치 없음·`2026-10-11 15:26:10 +09:00`·1422 를 돌려준다

### Task D1: 문서
- `docs/unverified.md` 에 "사진 기록 1단계" 절: XApp 위치 동기화를 켜고 찍은 사진의 GPS 가 읽히는지, 남반구·서경 사진(가짜 자료로만 확인)
- `docs/photo-log.prd.md` 1단계 `in-progress`, 계획 연결

---

## Testing Strategy

### Unit Tests

| Test | Input | Expected Output | Edge Case? |
|---|---|---|---|
| 북위·동경 | `N` 35/1 39/1 312/10, `E` 139/1 42/1 0/1 | (35.6587, 139.7) 근처, 소수 넷째 자리 | |
| 남위·서경 | `S`, `W` | 둘 다 음수 | ✓ |
| 표본처럼 값이 모두 0 | 방향 NUL, `0/0` ×3 | location null | ✓ |
| GPS IFD 없음 | IFD0 에 `0x8825` 없음 | location null, 나머지 정상 | |
| 분모 0 하나 | `35/1 0/0 0/1` | location null | ✓ |
| 범위 밖 | 위도 95° | location null | ✓ |
| 촬영 시각 + 시간대 | `2026:10:11 15:26:10`, `+09:00` | shotAt 2026-10-11 15:26:10, offset 9h | |
| 음의 시간대 | `-05:30` | −5h30m | ✓ |
| 시간대 없음 | `0x9011` 없음 | offset null, key null | |
| 빈 시각 | `0000:00:00 00:00:00` | shotAt null | ✓ |
| 후지 사진 | MakerNote FilmMode 0x700, ImageCount 1422 | recipe 의 filmSimulation 0x10, imageCount 1422, key `X-T5|2026-10-11T15:26:10+09:00|1422` | |
| 후지가 아닌 MakerNote | `NIKON...` | recipe 빈 맵, 예외 없음 | ✓ |
| MakerNote 없음 | | recipe 빈 맵 | |
| 빅 엔디언 | 같은 값 | 같은 결과 | ✓ |
| JPEG 아님 | PNG 머리 | `ImportException` | ✓ |
| 실제 표본 자료 | `test/fixtures/x_t5_eterna.jpg` | Eterna, 위치 없음, 15:26:10 +09:00, 1422 | |
| RATIONAL 위치 | `jpeg_exif_test` | 값 영역에서 읽음 | |

### Edge Cases Checklist
- [x] 빈 값 (GPS 0, 시각 0)
- [x] 깨진 값 (분모 0, 위치 태그 2개, 잘린 파일은 기존 시험)
- [x] 엔디언
- [ ] 동시 접근 — 순수 함수라 해당 없음
- [ ] 권한 — 2단계

---

## Validation Commands

```bash
cd Project/recipe-slot-manager
flutter analyze
dart format --set-exit-if-changed lib test tool
flutter test
```
EXPECT: 문제 없음, 바뀐 파일 없음, 전체 통과 (Skipped 0). 빌드는 Dart 코드만 바뀌므로 `flutter build macos --debug` 한 번.

## Acceptance Criteria
- [ ] 기존 237개 시험이 그대로 통과한다
- [ ] Testing Strategy 의 시험이 모두 있고 통과한다
- [ ] 시험 자료에 일련번호·썸네일·GPS 값이 없다
- [ ] `flutter analyze` 문제 없음

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| XApp 이 위치 동기화 사진에서도 GPS 를 지운다 | M | H | 이번 단계로는 알 수 없다. `docs/unverified.md` 에 남기고, 위치 없음 묶음이 있어 기능은 동작한다 |
| `0x1438` 이 촬영 번호가 아니다 | L | M | 표본 두 장이 1 차이로 이어진다. 틀리면 키만 바뀌고 6단계 전에 고친다 |
| 시험 자료에 개인 정보가 남는다 | L | H | 도구가 지운 뒤 일련번호 문자열·썸네일이 없음을 시험으로 확인 |

## Notes
- 표본 레시피(Eterna, DR400, 그레인 강·대, 하이라이트 −2, 섀도 +1, 컬러 +3, 클래리티 +1, NR −4, CC 강, FX 블루 강, WB 오토 R+4 B−7)가 카메라에 넣은 값과 같은지 사용자가 확인하면 `fuji_makernote.dart` 표의 "X-T5 표본으로 확인하기 전" 문구를 고친다
