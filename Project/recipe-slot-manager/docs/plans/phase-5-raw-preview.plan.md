# Plan: RAW 미리보기 (5단계)

## Summary
내 RAF(RAW) 한 장을 카메라에 보내고, 레시피 두 개를 각각 적용해 카메라 프로세서로 현상한 JPEG 두 장을 나란히 본다. 현상은 카메라가 하므로 앱에 RAW 엔진이 필요 없다. 실기기 시험은 할 수 없으므로 프로토콜은 가짜 카메라로, 화면은 위젯 시험으로 확인한다.

## User Story
As X-T5 사용자, I want 내가 찍은 RAW 에 레시피 A·B 를 적용한 결과를 나란히 보기를, so that 하이라이트 −1 과 +1 이 실제로 어떻게 다른지 슬롯에 넣기 전에 안다.

## Problem → Solution
레시피 값의 효과는 카메라에 넣고 찍어 봐야 안다 → 앱에서 RAF 하나와 레시피 두 개를 고르면 카메라가 현상한 두 결과를 나란히 보여 준다.

## Metadata
- **Complexity**: Large (새 PTP 흐름 하나, 큰 파일 전송, 새 화면)
- **Source PRD**: `Project/recipe-slot-manager/docs/prd.md`
- **PRD Phase**: 5. RAW 미리보기
- **Estimated Files**: 약 16개 (Dart 7, Swift 1, Kotlin 1, 시험 6, 문서 1)
- **커밋 단위**: 묶음 A–D 마다 하나 이상

---

## 프로토콜 (FilmKit `src/ptp/session.ts`, `src/profile/d185.ts`, MIT. X100VI 에서 확인, X-T5 미확인)

### 순서
1. **RAF 보내기**
   - `0x900C` SendObjectInfo, 매개변수 `[0, 0, 0]`, 데이터 = PTP ObjectInfo. ObjectFormat 은 반드시 `0xF802`(다르면 카메라가 말없이 무시), CompressedSize = RAF 크기, 파일 이름 PTP 문자열 `FUP_FILE.dat`, 날짜·키워드는 빈 문자열(0 한 바이트), 나머지 0
   - `0x900D` SendObject2, 매개변수 없음, 데이터 = RAF 전체. 시간 제한 60초
2. **기준 프로필 읽기**: `GetDevicePropValue(0xD185)`. RAF 를 보낸 뒤에만 값이 있다(비어 있으면 실패)
3. **레시피마다 현상**
   - 기준 프로필을 복사해 레시피 값만 고친 프로필을 `SetDevicePropValue(0xD185)` 로 쓴다
   - `SetDevicePropValue(0xD183)` 에 u16 `0` 을 써서 변환을 시작한다
   - `GetObjectHandles(0xFFFFFFFF, 0, 0)` 를 1초마다(최대 30초) 불러 핸들이 생기면 첫 핸들을 `GetObject` 로 받고(시간 제한 60초) `DeleteObject` 로 지운다(실패해도 무시)

### D185 프로필 형식 (카메라 기본 625바이트)
- 첫 u16 = 매개변수 개수 n. 마지막 `n × 4` 바이트가 int32(리틀 엔디언) 매개변수 배열
- 고치지 않은 칸은 그대로 둔다(그 칸은 RAF 의 EXIF 값으로 현상된다)
- 칸 번호와 값 인코딩은 슬롯 속성과 같다 → 레시피 필드 표를 그대로 쓴다

| 칸 | 레시피 필드 | 값 |
|---|---|---|
| 6 | dynamicRange | 100 / 200 / 400 |
| 8 | filmSimulation | 슬롯과 같은 코드 |
| 9 | grain | 1–5 (슬롯과 같음) |
| 10 | colorChrome | 1–3 |
| 11 | smoothSkin | 1–3 |
| 12 | whiteBalance | 슬롯과 같은 코드 |
| 13 / 14 | wbShiftRed / wbShiftBlue | 그대로 |
| 15 | colorTemperature | K |
| 16 / 17 / 18 / 19 | highlight / shadow / color / sharpness | ×10, 부호 있는 int32 |
| 20 | noiseReduction | 슬롯과 같은 표(0x2000 등) |
| 25 | colorChromeFxBlue | 1–3 |
| 27 | clarity | ×10 |

모노 WC·MG 는 FilmKit 표에 칸이 없다 → 고치지 않는다(EXIF 값으로 현상). 노출 보정(칸 4)은 레시피 필드가 아니라 다루지 않는다.

---

## UX Design

### After (넓은 창)
```
┌ 레시피 │ 묶음 │ 카메라 슬롯 │ RAW 미리보기 │ 디자인 ┐
│ [RAF 고르기] DSCF0042.RAF (48 MB, 카메라에 보냄)       │
│ A [Classic Neg. 여름 ▾]      B [Nostalgic 저녁 ▾]     │
│ ┌──────────────┐ ┌──────────────┐  [현상]           │
│ │  A 결과 JPEG  │ │  B 결과 JPEG  │  A 3.2초 · B 3.0초 │
│ └──────────────┘ └──────────────┘                     │
```
휴대폰(좁은 배치)은 두 결과를 위아래로 쌓는다. 결과를 누르면 전체 화면으로 확대해 본다.

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| 탐색 | 네 목적지 | "RAW 미리보기" 추가(다섯) | 아래 탭도 다섯 |
| RAF | - | 파일 고르기 → 카메라로 보냄 | 연결 전이면 안내, 보내는 동안 진행 표시와 다른 버튼 비활성 |
| 레시피 A·B | - | 보관함에서 고르기 | 같은 RAF 로 몇 번이고 다시 현상 |
| 결과 | - | 나란히(넓은 창)·위아래(휴대폰), 누르면 확대 | 저장은 하지 않는다 |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `lib/camera/fuji_camera.dart` | 25-35, 185-200 | `_send`·transaction ID. RAW 흐름이 같은 세션을 쓴다 |
| P0 | `lib/ptp/ptp_transport.dart` | all | `send` 계약. 시간 제한을 더한다 |
| P0 | `lib/camera/android_ptp_transport.dart` | 85-130 | 응답 모으기. 큰 데이터에서 복사가 O(n²) |
| P0 | `lib/recipe/recipe_fields.dart` | all | 필드 인코딩(`encode`, `ScaleField.multiplier`) |
| P1 | `macos/Runner/PtpChannel.swift` | 10, 95-145 | 명령 시간 제한 5초 고정 |
| P1 | `android/.../PtpChannel.kt` | 28-32, 165-195 | 쓰기·읽기 크기와 시간 제한 |
| P1 | `lib/ui/import_menu.dart`, `lib/import/file_pick.dart` | all | 파일 고르기, `session.run`, 바쁨 확인 |
| P2 | `test/support/fake_ptp_transport.dart` | all | 가짜 카메라. RAW 명령을 더한다 |

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `lib/ptp/ptp_codes.dart` | UPDATE | `GetObjectHandles 0x1007`, `GetObject 0x1009`, `DeleteObject 0x100B`, Fuji `SendObjectInfo 0x900C`, `SendObject2 0x900D`, `FujiProp.rawProfile 0xD185`, `startRawConversion 0xD183`, `rafFormat 0xF802` |
| `lib/ptp/ptp_transport.dart` | UPDATE | `send(command, {data, timeout})` |
| `lib/camera/fuji_camera.dart` | UPDATE | `command(op, params, {data, timeout})` 를 공개. 슬롯 작업도 이것을 쓴다 |
| `lib/camera/raw_developer.dart` | CREATE | RAF 보내기, 기준 프로필, 레시피별 현상 |
| `lib/camera/d185_profile.dart` | CREATE | 기준 프로필 + 레시피 값 → 고친 프로필 |
| `lib/camera/macos_ptp_transport.dart`, `macos/Runner/PtpChannel.swift` | UPDATE | 명령별 시간 제한 |
| `lib/camera/android_ptp_transport.dart`, `android/.../PtpChannel.kt` | UPDATE | `BytesBuilder` 로 모으기, 읽기 시간 제한, 쓰기 1 MiB 씩, 읽기 버퍼 1 MiB |
| `lib/import/file_pick.dart` | UPDATE | `pickRaf()` (`raf`, UTI `com.fuji.raw-image`) |
| `lib/ui/raw_preview_page.dart` | CREATE | RAF 고르기, 레시피 A·B, 현상, 결과 |
| `lib/ui/app_shell.dart` | UPDATE | 목적지 "RAW 미리보기" |
| `test/support/fake_ptp_transport.dart` | UPDATE | RAW 명령 응답 |
| `test/camera/*`, `test/ui/raw_preview_test.dart` | CREATE / UPDATE | |
| `docs/prd.md`, `docs/unverified.md` | UPDATE | 상태, 미확인 항목 |

## NOT Building

- 결과 JPEG 저장·공유 - 보기만 한다
- 레시피 값을 화면에서 바로 바꿔 가며 다시 현상하는 편집기 - 레시피 편집은 편집 화면에서
- 노출 보정, 모노 WC·MG 적용 - D185 칸이 확인되지 않았다
- 여러 RAF 한꺼번에 - 한 장씩
- 분할(슬라이더) 비교 - 나란히·위아래로 충분하다

---

## Step-by-Step Tasks

### 묶음 A: 큰 데이터를 보낼 수 있는 전송

#### Task A1: 명령별 시간 제한
- **IMPLEMENT**: `PtpTransport.send(..., {Duration? timeout})`. macOS 는 채널 인자 `timeout`(초)로 Swift `sendTimeout` 을 대신하고, 없으면 지금처럼 5초. Android 는 `read` 인자 `timeoutMs` 로 Kotlin bulk 시간 제한을 대신한다
- **VALIDATE**: 두 전송 시험에서 채널 인자에 시간 제한이 실린다

#### Task A2: Android 큰 데이터
- **IMPLEMENT**: Dart 응답 모으기를 `BytesBuilder` 로(복사 한 번). Kotlin `write` 는 1 MiB 씩 나눠 보내고, `read` 버퍼를 1 MiB 로
- **GOTCHA**: 0바이트 패킷 판단은 전체 길이 기준 그대로
- **VALIDATE**: 20 MB 데이터 컨테이너가 64 KiB 패킷 수백 개로 와도 1초 안에 모인다는 시험

### 묶음 B: RAW 현상 흐름 (가짜 카메라, TDD)

#### Task B1: 프로필 고치기
- **IMPLEMENT**: `patchD185(Uint8List base, Map<String, double> values)`. 위 칸 표로 적용 가능한 필드(`isApplicable`)만 고친다. 눈금 필드는 `(value × multiplier).round()` 부호 있게, 나머지는 `field.encode(value)`
- **VALIDATE**: 칸 위치, 부호(하이라이트 −1.5 → −15), 고치지 않은 칸은 그대로, 흑백이면 컬러 칸 그대로, 프로필이 너무 짧으면 `FormatException`

#### Task B2: RawDeveloper
- **IMPLEMENT**: `loadRaf(bytes)` → ObjectInfo 조립(0xF802, 크기, `FUP_FILE.dat`) → 0x900C → 0x900D(60초) → D185 읽기(비어 있으면 실패) → 기준 프로필 저장. `develop(values)` → D185 쓰기 → D183 `0` → 핸들 1초 간격 최대 30초 → GetObject(60초) → DeleteObject. 걸린 시간을 로그에 남긴다
- **MIRROR**: `FujiCamera` 의 로그·시간 측정(`_startTiming`), 응답 코드 오류는 `SlotWriteException` 대신 `RawDevelopException`
- **GOTCHA**: 기다리는 시간과 간격은 생성자 인자(시험에서 0). 데이터 컨테이너 안 핸들 배열은 `u32 개수 + u32 × n`
- **VALIDATE**: 가짜 카메라로 명령 순서·매개변수, ObjectInfo 바이트, 현상 결과 JPEG, 핸들이 늦게 생기는 경우, 30초 넘으면 실패, 각 단계 응답 실패

### 묶음 C: 화면

#### Task C1: RAW 미리보기 화면
- **IMPLEMENT**: RAF 고르기(`pickRaf`, 전체 읽기) → `session.run('RAF 보내기', developer.loadRaf)`. 레시피 A·B 드롭다운(보관함). "현상" → A·B 차례로 `develop`, 결과 `Image.memory`. 넓은 창 나란히, 좁은 배치 위아래. 결과를 누르면 `InteractiveViewer` 전체 화면. 미연결·바쁨·RAF 없음·레시피 없음 안내
- **VALIDATE**: 가짜 카메라 위젯 시험: RAF 보내기 → 현상 → 두 결과, 미연결 안내, 412×915 넘침 없음

#### Task C2: 셸 목적지
- **IMPLEMENT**: `_destinations` 에 `(Icons.photo_filter_outlined, 'RAW 미리보기')` 를 디자인 앞에
- **VALIDATE**: 휴대폰 크기 시험의 목적지 목록에 더한다(360 dp·큰 글꼴 포함)

### 묶음 D: 확인과 문서
- 전체 시험·분석·형식·macOS·APK 빌드
- `docs/unverified.md` 에 5단계 항목, PRD 상태

---

## Testing Strategy

| Test | Input | Expected | Edge? |
|---|---|---|---|
| ObjectInfo | RAF 48 MB | 0xF802, 크기, `FUP_FILE.dat` | |
| 프로필 고치기 | 기준 + {highlight −1.5, grain 4} | 칸 16 = −15, 칸 9 = 4, 나머지 그대로 | |
| 흑백 | Acros + 컬러 2 | 칸 8 = 0x0C, 칸 18 그대로 | ✓ |
| 짧은 프로필 | 매개변수 개수 > 길이 | FormatException | ✓ |
| 현상 순서 | 레시피 하나 | D185 쓰기 → D183 → 핸들 → GetObject → DeleteObject | |
| 늦은 결과 | 핸들이 세 번째 조회에 생김 | JPEG | ✓ |
| 시간 초과 | 핸들이 끝내 없음 | RawDevelopException | ✓ |
| RAF 전 현상 | loadRaf 없이 develop | RawDevelopException | ✓ |
| 큰 응답 | 20 MB 를 64 KiB 씩 | 1초 안에 모임 | ✓ |
| 화면 | 가짜 카메라 | 두 결과, 안내, 넘침 없음 | |

## Validation Commands

```bash
cd Project/recipe-slot-manager
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
flutter build macos --debug --dart-define-from-file=supabase.example.json
flutter build apk --debug --dart-define-from-file=supabase.example.json
```

## Acceptance Criteria
- [ ] 가짜 카메라에서 RAF 한 장에 레시피 둘을 적용한 결과 두 장이 화면에 나란히 보인다
- [ ] 명령 순서·인자·프로필 칸이 FilmKit 자료와 같다
- [ ] 큰 파일 전송 경로(시간 제한, Android 모으기)가 시험으로 덮인다
- [ ] 검증 명령 전부 통과

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| X-T5 의 D185 칸 번호가 X100VI 와 다름 | 중 | 높음 | 칸 표를 한 곳에 두고, 실기기 확인을 `unverified.md` 에 둔다 |
| RAF(약 50 MB) 전송이 휴대폰에서 느리거나 메모리가 부족 | 중 | 중 | 1 MiB 씩 쓰기, 진행 중 표시. 실기기 측정은 미확인 항목 |
| `ImageCaptureCore` 가 50 MB 데이터 명령을 한 번에 받는가 | 중 | 높음 | 실기기 확인 항목. 실패하면 Swift 에서 나눠 보내는 방법을 찾는다 |
| 현상 결과가 다른 사진 객체와 섞임(카메라 메모리 카드의 사진) | 낮음 | 중 | FilmKit 처럼 첫 핸들을 쓰되, 받은 바이트가 JPEG(FF D8)인지 확인 |

## Notes
- 프로토콜과 프로필 칸은 FilmKit(MIT, X100VI 확인) 기준이다. 이 프로젝트의 1단계 슬롯 인코딩도 같은 출처다

## 구현 중 바뀐 점
- 휴대폰 배치 기준(600·500)을 `AppShell` 에서 `AppBreakpoints`(tokens)로 옮겨 셸과 RAW 미리보기 화면이 함께 쓴다
- `RawDeveloper` 는 셸이 들고 있어, 다른 탭을 다녀와도 보낸 RAF(이름 포함)를 기억한다
- `CameraSession.run` 이 `RawDevelopException` 도 로그 문구로 바꾼다
- 레시피는 A 하나만 골라도 현상할 수 있다 (B 는 선택)
- FilmKit 마지막 갱신은 2026-03-26(v0.3.2), `d185.ts` 는 첫 커밋(2026-03-19) 그대로다
- 리뷰 반영: 현상 시작 직전의 객체 목록을 기록해 두고 그 뒤 새로 생긴 객체만 결과로 받고 지운다(메모리 카드 사진, 앞 현상이 늦게 남긴 결과를 건드리지 않는다). 다시 연결하면 RAF 를 다시 보내야 한다(`FujiCamera.sessionNumber`). 결과는 폭 2048 px(확대 4096 px)로 줄여 그린다. 결과에 화면 낭독기 설명, 빈 보관함 안내
