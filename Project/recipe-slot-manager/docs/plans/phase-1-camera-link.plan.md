# Plan: 카메라 연결 기반 (macOS)

## Summary
macOS에서 X-T5와 USB PTP로 연결해 C1–C7 슬롯 7개를 읽고, 슬롯 하나를 쓰고, 다시 읽어 검증하고, 7슬롯 백업을 파일로 남겨 복원하는 Flutter 앱의 첫 골격을 만든다. PTP 명령 조립과 슬롯 순서 제어는 Dart에 두고, Swift는 `ImageCaptureCore`로 바이트만 주고받는다. 2단계(레시피 모델, Supabase)와 3단계(Android)가 그대로 올라설 수 있게 전송 계층을 인터페이스 하나로 분리한다.

## User Story
As X-T5 사용자, I want 맥에 카메라를 꽂으면 C1–C7의 현재 값이 보이고 슬롯을 쓰고 되돌릴 수 있기를, so that 다음 단계에서 묶음 덮어쓰기를 안심하고 만들 수 있다.

## Problem → Solution
X-T5가 공개 자료(X100VI 기준)대로 응답하는지 모르고, 7슬롯 쓰기에 몇 초 걸리는지도 모른다 → 실제 값 표, 쓰기·검증·복원 동작, 왕복 시간 측정치가 생긴다.

## Metadata
- **Complexity**: Large (신규 프로젝트, 네이티브 연동)
- **Source PRD**: `Project/recipe-slot-manager/docs/prd.md`
- **PRD Phase**: 1. 카메라 연결 기반 (macOS)
- **Estimated Files**: 약 16개 (Dart 9, 시험 5, Swift·설정 2+)

---

## UX Design

### Before
```
카메라 메뉴 → 커스텀 설정 → C1 … C7 을 하나씩 열어 값 확인·수정
```

### After
```
┌ Recipe Slot Manager ─────────────────────────────┐
│ ● X-T5 연결됨          [7슬롯 읽기] [백업] [복원] │
├──────┬────────┬────────┬─────┬────────┬──────────┤
│ 속성 │ C1     │ C2     │ ... │ C7     │          │
│ 이름 │ Kodak..│ Night..│     │ ...    │          │
│ D192 │ 0x0011 │ 0x0013 │     │        │          │
│ ...  │        │        │     │        │          │
├──────┴────────┴────────┴─────┴────────┴──────────┤
│ 셀 클릭 → 값 수정 → [이 슬롯 쓰기] → 검증 결과     │
│ 로그: 슬롯 1개 읽기 1.2s, 왕복 평균 41ms          │
└──────────────────────────────────────────────────┘
```
1단계는 확인용 화면이다. 값은 원시 값(16진수 + 정수)으로 보여 주고, 사람이 읽는 값 변환은 2단계에서 한다.

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| 슬롯 확인 | 카메라 메뉴 7번 진입 | 표 한 장 | 읽기 중 다른 버튼 비활성 |
| 슬롯 수정 | 카메라 다이얼 | 셀 값 입력 후 쓰기 | 쓰기 전 자동 백업 |
| 되돌리기 | 없음 | 백업 파일 선택 → 복원 | 읽기 전용 속성은 경고로 표시 |

---

## Mandatory Reading

저장소에 기존 코드가 없다. 구현 전 아래 외부 자료를 읽는다.

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `Project/recipe-slot-manager/docs/analysis.md` | X-T5 슬롯 프로토콜 절 | 속성 코드 표 |
| P0 | [filmkit `src/ptp/session.ts`](https://github.com/eggricesoy/filmkit/blob/master/src/ptp/session.ts) | 160–230, 330–470 | 세션 열기, 슬롯 읽기·쓰기·검증 순서 (MIT) |
| P0 | [filmkit `src/ptp/container.ts`](https://github.com/eggricesoy/filmkit/blob/master/src/ptp/container.ts) | all | PTP 컨테이너 조립·해석 |
| P1 | [filmkit `src/ptp/constants.ts`](https://github.com/eggricesoy/filmkit/blob/master/src/ptp/constants.ts) | 40–130 | 명령·응답·속성 코드 |
| P1 | [filmkit `src/util/binary.ts`](https://github.com/eggricesoy/filmkit/blob/master/src/util/binary.ts) | all | PTP 문자열 인코딩 |
| P2 | Apple `ICCameraDevice.requestSendPTPCommand(_:outData:completion:)` | - | Swift 전송 API |

## External Documentation

| Topic | Source | Key Takeaway |
|---|---|---|
| 슬롯 선택 | filmkit session.ts `scanPresets` | `0xD18C`에 1–7 쓰기 → 100ms 대기 → `0xD18D`, `0xD18E–0xD1A5` 읽기. 끝나면 원래 슬롯으로 되돌림 |
| 쓰기 | filmkit session.ts `writePreset` | 슬롯 선택·이름 쓰기 실패만 치명적. 속성별 거부는 경고. 쓴 뒤 다시 읽어 바이트 비교 |
| 읽기 전용·조건부 속성 | filmkit session.ts 주석 | `D19C`(색온도), `D19F`(컬러), `D1A1`(고감도 NR)은 상황에 따라 거부된다 |
| 세션 충돌 | filmkit session.ts `openSession` | `SessionAlreadyOpen` 응답 시 닫고 재시도 |
| ICC 전송 | [Apple 문서](https://developer.apple.com/documentation/imagecapturecore/iccameradevice/requestsendptpcommand(_:outdata:completion:)) | 명령 버퍼 + 선택적 출력 데이터 → (입력 데이터, 응답 버퍼, 오류) |
| ICC 시간 초과 | [Apple 포럼 740412](https://developer.apple.com/forums/thread/740412) | 데이터 단계가 있는 명령에서 5초 이상 멈춘 사례가 있다 |
| ICC 권한 | [Apple 포럼 743100](https://developer.apple.com/forums/thread/743100) | 서명 방식에 따라 장치 검색이 실패한 사례. 개발 중에는 ad-hoc 서명으로 시작 |

```
KEY_INSIGHT: ImageCaptureCore는 장치 세션을 스스로 연다 (requestOpenSession).
APPLIES_TO: Task 4, Task 6
GOTCHA: Dart에서 PTP OpenSession(0x1002)을 따로 보내면 SessionAlreadyOpen이 날 수 있다. 세션 열기는 PtpTransport.connect의 책임으로 두고, FujiCamera는 OpenSession을 보내지 않는다.

KEY_INSIGHT: ICC에서 outData는 데이터 컨테이너가 아닌 값 바이트만 넘기는 것으로 보인다.
APPLIES_TO: Task 6
GOTCHA: 확인되지 않았다. 실기기 시험에서 SetDevicePropValue가 InvalidParameter(0x201D)로 실패하면 데이터 컨테이너로 감싸서 다시 시도한다.

KEY_INSIGHT: 명령 컨테이너의 transaction ID는 ICC가 덮어쓸 가능성이 높다.
APPLIES_TO: Task 2
GOTCHA: Dart는 증가하는 ID를 넣되, 응답 해석에서 ID 일치를 검사하지 않는다.
```

---

## Patterns to Mirror

저장소에 기존 Dart·Swift 코드가 없다. 아래는 이 계획이 처음 정하는 규칙이며, 2단계 이후 코드가 따른다.

### NAMING_CONVENTION
- 파일 `snake_case.dart`, 타입 `UpperCamelCase`, 멤버 `lowerCamelCase` (Effective Dart)
- PTP 코드 상수는 `abstract final class PtpOp { static const getDevicePropValue = 0x1015; }` 형태로 묶는다
- 속성 코드는 `int`로 다루고, 화면 표시는 `'D18E'` 4자리 대문자 16진수

### ERROR_HANDLING
- 전송 실패(장치 없음, 시간 초과)는 `PtpTransportException` 을 던진다
- 카메라 응답 코드가 OK(0x2001)가 아닌 것은 예외가 아닌 값(`PtpReply.code`)으로 돌려주고, 호출하는 쪽이 판단한다
- 슬롯 선택 실패만 `SlotWriteException`, 속성별 거부는 `SlotWriteResult.warnings`에 모은다 (filmkit `writePreset`과 같은 기준)

### LOGGING_PATTERN
- `CameraLog` 하나에 `(DateTime, String)` 기록을 쌓고 화면 하단에 보여 준다. 외부 로깅 패키지는 쓰지 않는다
- 각 PTP 왕복의 소요 시간을 `Stopwatch`로 재서 기록한다

### TEST_STRUCTURE
- `test/` 아래 `lib/`와 같은 경로, `*_test.dart`
- 카메라는 `FakePtpTransport`(응답을 미리 넣어 두는 가짜)로 대체하고, 보낸 명령 목록을 검사한다
- 대기 시간은 `FujiCamera(slotSwitchDelay: Duration.zero)`로 주입해 시험에서 0으로 만든다

---

## Files to Change

앱 루트: `Project/recipe-slot-manager/` (`docs/`는 그대로 둔다)

| File | Action | Justification |
|---|---|---|
| `pubspec.yaml`, `analysis_options.yaml` 등 | CREATE | `flutter create --platforms=macos,android --org dev.supsuphae --project-name recipe_slot_manager .` |
| `lib/ptp/ptp_codes.dart` | CREATE | 명령·응답·후지 속성 코드 |
| `lib/ptp/ptp_container.dart` | CREATE | 명령·데이터 컨테이너 조립, 응답 해석 |
| `lib/ptp/ptp_string.dart` | CREATE | PTP 문자열 인코딩·디코딩 |
| `lib/ptp/ptp_transport.dart` | CREATE | `PtpTransport` 인터페이스, `PtpReply`, `PtpTransportException` |
| `lib/camera/slot_snapshot.dart` | CREATE | 슬롯 1개의 이름 + 속성별 원시 바이트, JSON 변환 |
| `lib/camera/fuji_camera.dart` | CREATE | 7슬롯 읽기, 슬롯 쓰기·검증, 원래 슬롯 복귀, 시간 측정 |
| `lib/camera/slot_backup_store.dart` | CREATE | 백업 JSON 저장·목록·불러오기 |
| `lib/camera/macos_ptp_transport.dart` | CREATE | MethodChannel 구현 |
| `lib/camera/camera_log.dart` | CREATE | 로그 기록 |
| `lib/ui/slots_page.dart` | CREATE | 확인용 표 화면 |
| `lib/main.dart` | UPDATE | `SlotsPage` 실행 |
| `macos/Runner/PtpChannel.swift` | CREATE | `ICDeviceBrowser`, 세션, `requestSendPTPCommand` |
| `macos/Runner/MainFlutterWindow.swift` | UPDATE | 채널 등록 |
| `macos/Runner/DebugProfile.entitlements`, `Release.entitlements` | UPDATE | `com.apple.security.device.usb`, `com.apple.security.device.camera` |
| `macos/Runner/Info.plist` | UPDATE | `NSCameraUsageDescription` |
| `test/ptp/ptp_container_test.dart`, `ptp_string_test.dart` | CREATE | 바이트 단위 시험 |
| `test/camera/fuji_camera_test.dart`, `slot_snapshot_test.dart`, `slot_backup_store_test.dart` | CREATE | 순서·검증·백업 시험 |
| `test/support/fake_ptp_transport.dart` | CREATE | 가짜 전송 |
| `/.gitignore` (저장소 루트) | CREATE | `.tgrep/` 제외 |

## NOT Building

- 레시피 의미 변환(0x0011 → Classic Neg., 15 → +1.5) - 2단계
- 묶음, 비교 화면, 7슬롯 일괄 덮어쓰기 화면 - 2단계 (1단계에서는 측정만)
- Supabase, 로그인 - 2단계
- Android 전송 - 3단계 (`flutter create`에 android 플랫폼만 포함해 둔다)
- RAF 현상, EXIF, OCR, 블루투스 - 4–7단계
- 카메라 연결 끊김 자동 재연결 - 필요해지면 추가

---

## Step-by-Step Tasks

### Task 0: 개발 환경 (사용자 작업 포함)
- **ACTION**: Flutter macOS 빌드 도구를 갖춘다. 지금 Mac에는 Xcode와 Flutter가 없다
- **IMPLEMENT**:
  1. App Store에서 Xcode 설치 (사용자, 약 15GB)
  2. `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer && sudo xcodebuild -runFirstLaunch` (사용자, 관리자 암호 필요)
  3. `brew install --cask flutter`, `brew install cocoapods`
  4. `flutter doctor` 에서 Flutter, Xcode 항목 통과
- **GOTCHA**: Android 항목 실패는 3단계 전까지 무시한다
- **VALIDATE**: `flutter doctor` 출력의 Xcode 항목이 체크 표시

### Task 1: 프로젝트 생성
- **ACTION**: `Project/recipe-slot-manager/` 에서 `flutter create --platforms=macos,android --org dev.supsuphae --project-name recipe_slot_manager .`
- **IMPLEMENT**: 생성된 카운터 예제와 `test/widget_test.dart` 삭제. `pubspec.yaml`에 `path_provider` 추가. 저장소 루트 `.gitignore`에 `.tgrep/` 추가
- **GOTCHA**: 이미 있는 `docs/`는 건드리지 않는다
- **VALIDATE**: `flutter analyze` 오류 0, `flutter build macos --debug` 성공

### Task 2: PTP 컨테이너 (TDD)
- **ACTION**: `ptp_codes.dart`, `ptp_container.dart`
- **IMPLEMENT**:
  - 명령 컨테이너: `[u32 길이][u16 타입=1][u16 코드][u32 txId][u32 매개변수 × n]`, 모두 리틀 엔디언, 길이 = 12 + 4n
  - 데이터 컨테이너: 타입=2, 뒤에 값 바이트 (Android용, 1단계는 시험만)
  - 응답 해석: 바이트 6–7이 응답 코드, 12 이후가 매개변수
  - 코드: `GetDeviceInfo 0x1001`, `OpenSession 0x1002`, `CloseSession 0x1003`, `GetDevicePropValue 0x1015`, `SetDevicePropValue 0x1016`. 응답 `OK 0x2001`, `DevicePropNotSupported 0x200A`, `InvalidParameter 0x201D`, `SessionAlreadyOpen 0x201E`. 속성 `presetSlot 0xD18C`, `presetName 0xD18D`, `presetFirst 0xD18E`, `presetLast 0xD1A5`
- **IMPORTS**: `dart:typed_data`
- **GOTCHA**: `ByteData.setUint32(offset, v, Endian.little)` — 엔디언 인자를 빠뜨리면 빅 엔디언이 된다
- **VALIDATE**: `GetDevicePropValue(0xD18C)` 명령이 `10 00 00 00 01 00 15 10 01 00 00 00 8C D1 00 00` (txId=1)과 같다

### Task 3: PTP 문자열 (TDD)
- **ACTION**: `ptp_string.dart`
- **IMPLEMENT**: `[u8 글자 수(널 포함)][UTF-16LE 글자…][0x0000]`. 빈 문자열은 `[0x00]` 한 바이트
- **GOTCHA**: 카메라 이름 칸의 최대 길이는 미확인. 1단계는 읽은 이름을 그대로 다시 쓰는 경우만 다룬다
- **VALIDATE**: `"AB"` → `03 41 00 42 00 00 00`, 왕복 변환 일치

### Task 4: 전송 인터페이스와 가짜 전송
- **ACTION**: `ptp_transport.dart`, `test/support/fake_ptp_transport.dart`
- **IMPLEMENT**:
  ```dart
  abstract interface class PtpTransport {
    Future<void> connect();          // 장치 찾기 + 세션 열기
    Future<PtpReply> send(Uint8List command, {Uint8List? data});
    Future<void> disconnect();
    String? get modelName;
  }
  final class PtpReply { final int code; final Uint8List data; }
  ```
  가짜 전송은 슬롯별 속성 맵을 갖고 `0xD18C` 선택에 따라 다른 값을 돌려준다. 특정 속성에 거부 응답을 넣을 수 있고, 보낸 명령을 기록한다
- **GOTCHA**: 인터페이스 구현은 macOS·Android·가짜 셋이 된다 (PRD 3단계)
- **VALIDATE**: 가짜 전송 자체의 시험은 두지 않고 Task 5 시험에서 함께 확인

### Task 5: FujiCamera (TDD)
- **ACTION**: `slot_snapshot.dart`, `fuji_camera.dart`, `camera_log.dart`
- **IMPLEMENT**:
  - `SlotSnapshot { int slot; String name; Map<int, Uint8List> props; }` + `toJson`(속성은 `'D18E': '0b00'` 16진 문자열)/`fromJson`
  - `Future<List<SlotSnapshot>> readAllSlots()`: 현재 슬롯 읽기 → 1–7 순서로 선택·대기·이름·24속성 읽기 → 원래 슬롯 복귀. `DevicePropNotSupported` 속성은 건너뛴다
  - `Future<SlotWriteResult> writeSlot(SlotSnapshot target, {SlotSnapshot? current})`: 선택 → 이름이 다를 때만 쓰기 → `current`와 바이트가 다른 속성만 쓰기 → 쓴 속성 다시 읽어 비교. 결과 `{written, warnings, mismatched}`
  - `Future<List<SlotWriteResult>> restore(List<SlotSnapshot> backup)`: 각 슬롯을 `current` 없이(전체) 쓴다
  - 모든 왕복을 `Stopwatch`로 재서 `CameraLog`에 남기고, `readAllSlots`·`writeSlot` 전체 시간도 남긴다
- **MIRROR**: ERROR_HANDLING, filmkit `scanPresets`/`writePreset` 순서
- **GOTCHA**: 슬롯 선택 직후 100ms 대기 (생성자 인자, 시험에서 0). 실기기에서 더 줄일 수 있는지는 측정 후 결정
- **VALIDATE**: 시험 항목은 아래 Testing Strategy

### Task 6: macOS 전송 (Swift)
- **ACTION**: `PtpChannel.swift`, `MainFlutterWindow.swift`, entitlements, Info.plist, `macos_ptp_transport.dart`
- **IMPLEMENT**:
  - 채널 이름 `recipe_slot_manager/ptp`, 메서드 `connect`, `send`(`command: FlutterStandardTypedData`, `data: FlutterStandardTypedData?` → `{code: Int, data: FlutterStandardTypedData}`), `disconnect`
  - `connect`: `ICDeviceBrowser.requestControlAuthorization` → 브라우저 시작(카메라, 로컬) → `usbVendorID == 0x04CB`인 `ICCameraDevice` 대기(10초) → `requestOpenSession` → `deviceDidBecomeReady` 대기 → 모델 이름 반환
  - `send`: `requestSendPTPCommand(command, outData: data)` → 응답 버퍼 바이트 6–7을 code로, 입력 데이터를 data로 돌려준다. 오류는 `FlutterError(code: "ptp", …)`
  - Dart `MacosPtpTransport`는 `PlatformException`을 `PtpTransportException`으로 바꾼다
- **IMPORTS**: `ImageCaptureCore`, `FlutterMacOS`
- **GOTCHA**:
  - 사진 앱·이미지 캡처 앱이 카메라를 먼저 잡으면 실패할 수 있다. 시험 전 종료
  - 카메라 설정 `PC 연결 모드 → USB RAW 변환/백업 복원` 이 아니면 장치가 PTP로 보이지 않는다
- **VALIDATE**: 실기기 수동 시험 (Manual Validation)

### Task 7: 백업 저장소 (TDD)
- **ACTION**: `slot_backup_store.dart`
- **IMPLEMENT**: 디렉터리를 생성자로 받는다(앱에서는 `getApplicationSupportDirectory()/backups`). 파일 `slots-YYYYMMDD-HHmmss.json`, 내용 `{ "model": "X-T5", "createdAt": "<ISO 8601 UTC>", "slots": [SlotSnapshot.toJson…] }`. `save`, `list`(최신순), `load`
- **GOTCHA**: 시험은 `Directory.systemTemp.createTempSync()` 사용
- **VALIDATE**: 저장 → 불러오기 결과가 원본과 같다

### Task 8: 확인용 화면
- **ACTION**: `slots_page.dart`, `main.dart`
- **IMPLEMENT**: 연결 버튼, 7슬롯 읽기, 표(행: 이름 + 24속성, 열: C1–C7, 셀: 16진수와 int16 값), 셀 편집 → "이 슬롯 쓰기"(쓰기 전 자동 백업 → `writeSlot` → 결과 표시), 백업 목록에서 복원, 하단 로그. 작업 중에는 모든 버튼 비활성
- **GOTCHA**: 상태 관리 패키지를 쓰지 않는다. `StatefulWidget` 하나로 충분하다. 2단계에서 화면 구조를 정할 때 다시 본다
- **VALIDATE**: `flutter run -d macos` 로 카메라 없이 실행 시 "카메라 없음" 상태가 오류 없이 보인다

---

## Testing Strategy

### Unit Tests

| Test | Input | Expected Output | Edge Case? |
|---|---|---|---|
| 명령 컨테이너 조립 | GetDevicePropValue, 0xD18C, txId 1 | 16바이트 예시와 일치 | |
| 매개변수 없는 명령 | CloseSession | 길이 12 | ✓ |
| 응답 해석 | `0C 00 00 00 03 00 01 20 …` | code 0x2001 | |
| 짧은 응답 | 8바이트 | `FormatException` | ✓ |
| PTP 문자열 | "AB" / "" / 한글 "야간" | 인코딩 일치, 왕복 일치 | ✓ |
| 7슬롯 읽기 순서 | 가짜 전송 | 선택 1→7, 각 25회 읽기, 마지막에 원래 슬롯 선택 | |
| 미지원 속성 | D191이 0x200A | 그 속성만 빠지고 계속 | ✓ |
| 슬롯 선택 실패 | D18C 쓰기 0x201D | `SlotWriteException` | ✓ |
| 바뀐 값만 쓰기 | current와 2개 다름 | Set 명령 2회 | |
| 속성 거부 | D19C 쓰기 0x201D | warnings에 D19C, 나머지 계속 | ✓ |
| 검증 불일치 | 쓴 값과 다른 값을 돌려줌 | mismatched에 기록 | ✓ |
| 백업 왕복 | 7슬롯 | 저장·불러오기 일치, list 최신순 | |
| SlotSnapshot JSON | props 3개 | 왕복 일치 | |

### Edge Cases Checklist
- [x] 빈 문자열 이름
- [ ] 최대 길이 이름 - 카메라 한도 미확인, 1단계 제외
- [x] 미지원·거부 속성
- [ ] 동시 접근 - 화면에서 작업 중 버튼 비활성으로 막는다
- [x] 전송 실패 (`PtpTransportException`)
- [ ] 권한 거부 - 실기기 수동 확인

---

## Validation Commands

모두 `Project/recipe-slot-manager/` 에서 실행한다.

### Static Analysis
```bash
flutter analyze
```
EXPECT: No issues found

### Unit Tests
```bash
flutter test
```
EXPECT: 전부 통과, Skipped 0

### Build
```bash
flutter build macos --debug
```
EXPECT: 빌드 성공

### Manual Validation (X-T5 필요)
- [ ] 카메라 `PC 연결 모드` 를 `USB RAW 변환/백업 복원` 으로 설정, 사진 앱·이미지 캡처 종료
- [ ] 연결 → 모델 이름 "X-T5" 표시
- [ ] 7슬롯 읽기 → 카메라 메뉴의 C1–C7 이름과 일치, D192(필름 시뮬레이션) 값을 analysis.md 표와 대조
- [ ] 읽기 전후 카메라의 현재 선택 슬롯이 같다
- [ ] 백업 파일 생성 확인
- [ ] C7의 하이라이트(D19D) 하나를 바꿔 쓰기 → 카메라 메뉴에서 바뀐 값 확인
- [ ] 백업에서 복원 → 카메라 메뉴에서 원래 값 확인
- [ ] 로그의 슬롯 1개 쓰기 시간 × 7 이 10초 이내인지 기록 (PRD 열린 질문)
- [ ] X-T5 값 중 analysis.md와 다른 것을 `docs/analysis.md` 에 기록

---

## Acceptance Criteria
- [ ] Task 0–8 완료
- [ ] `flutter analyze`, `flutter test`, `flutter build macos --debug` 통과
- [ ] 실기기 수동 검증 항목 통과 (사용자 시험)
- [ ] 측정한 왕복 시간과 X-T5 값 차이가 `docs/analysis.md` 에 기록됨

## Completion Checklist
- [ ] 이 계획의 이름·오류·로그·시험 규칙을 따름
- [ ] 하드코딩된 값은 `ptp_codes.dart` 상수로만
- [ ] 2단계 이후 범위를 끌어오지 않음

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| ICC가 X-T5를 찾지 못하거나 권한 요청이 실패 | M | H | ad-hoc 서명으로 시작. 실패하면 FilmKit 웹앱(Chrome)으로 카메라 자체 응답을 먼저 확인해 원인을 나눈다 |
| ICC `outData` 형식이 예상과 다름 | M | M | InvalidParameter 시 데이터 컨테이너로 감싸 재시도 (Task 6 GOTCHA) |
| ICC 데이터 단계 명령의 시간 초과 (포럼 사례) | L | H | `send`에 5초 제한, 로그로 어느 명령인지 남김 |
| X-T5 속성 코드가 자료와 다름 | M | M | 원시 값 표로 그대로 보이게 하고 차이를 기록 |
| Xcode 설치 지연 | M | M | Task 2–5, 7은 Flutter만 있으면 `flutter test`로 진행 가능 |

## Notes
- **Confidence: 6/10.** Dart 쪽(Task 2–5, 7)은 시험으로 끝까지 확인할 수 있다. Swift 쪽(Task 6)은 실기기 없이는 확인할 수 없다.
- 실기기 시험은 사용자가 나중에 하기로 했다. 그 전까지 Task 6은 빌드 성공과 "카메라 없음" 처리까지만 확인한다.

### 구현 중 바뀐 점 (Task 2–5, 7)
- `path_provider` 는 Task 8로 미룬다. Xcode 없이는 네이티브 빌드 훅(objective_c)이 링크에 실패해 `flutter test` 전체가 멈춘다. 백업 저장소는 디렉터리를 생성자로 받는다.
- 백업 파일 이름에 밀리초를 붙였다 (`slots-YYYYMMDD-HHmmss-SSS.json`). 같은 초의 백업이 덮어써지지 않게 한다.
- 데이터 컨테이너 조립은 3단계(Android)로 미룬다. macOS 전송은 값 바이트만 넘긴다.
- `PtpTransport.connect()` 가 모델 이름을 돌려준다 (`modelName` getter 대신).
- 이름 쓰기 거부는 경고로 처리한다. 슬롯 선택 거부만 `SlotWriteException` 이다.
- Task 6의 Swift `send` 는 응답 컨테이너 바이트를 그대로 돌려주고, 응답 코드는 Dart `ptpResponseCode` 로 읽는다.

### 구현 중 바뀐 점 (Task 6, 8)
- `ICDeviceBrowser.requestControlAuthorization` 은 macOS에서 쓸 수 없다(iOS 전용). macOS는 샌드박스 엔타이틀먼트 `device.usb`, `device.camera` 로 접근하고, 연결은 바로 `browser.start()` 로 시작한다.
- macOS 27 SDK 에서는 `ICDeviceDelegate.device(_:didOpenSessionWithError:)` 가 필수다.
- `PtpChannel.swift` 는 `xcodeproj` gem 으로 Runner 대상에 등록했다.
- 값 수정 대화 상자는 `TextEditingController` 대신 `TextFormField(initialValue:, onChanged:)` 를 쓴다. 닫히는 애니메이션 중에 해제된 컨트롤러를 쓰는 오류를 막는다.

### 리뷰 반영
- 쓰기·복원 직전에 카메라에서 7슬롯을 새로 읽어 백업하고, 그 값을 비교 기준으로 쓴다. 쓰기가 중간에 실패하면 표를 비워 다시 읽게 한다.
- 백업 파일은 슬롯 번호(1–7, 중복 없음), 이름 길이(254자), 속성 코드(`D18E`–`D1A5`), 값(짝수 길이 16진수)을 검사한 뒤에만 쓴다. 다른 모델의 백업은 복원하지 않는다. 저장은 임시 파일에 쓰고 옮긴다.
- 값 입력은 바이트 수에 맞는 범위(2바이트 -32768–65535, 4바이트 -2147483648–4294967295)만 받는다. 변환은 `lib/camera/prop_value.dart`.
- 응답 컨테이너 타입(3)을 검사한다. ImageCaptureCore 완료 블록의 인자 순서가 예상과 다르면 여기서 오류로 드러난다.
- Swift: 연결마다 시간 제한을 따로 두고 취소한다. `disconnect`, 카메라 분리, 세션 열기 실패는 대기 중인 연결을 바로 끝낸다. connect 를 기다리지 않을 때 다시 꽂힌 카메라에는 연결하지 않는다. PTP 응답 시간이 초과되면 세션을 닫는다. 명령은 한 번에 하나만 보낸다. `cameraDeviceCanAcceptPTPCommands` 가 없는 장치는 연결하지 않는다.
