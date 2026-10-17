# Plan: Android (3단계)

## Summary
2단계의 레시피·묶음·비교·7슬롯 쓰기를 Android 휴대폰에서 쓴다. 대상 기기는 갤럭시 S26 울트라다. 카메라 연결은 Kotlin `UsbManager` bulk 전송으로 하고, PTP-over-USB 컨테이너 조립과 해석은 Dart 에 두어 가짜 채널로 시험한다. 휴대폰 화면은 아래 탭 막대로 바꾸는 **임시 틀**이다. 디자인 시스템을 나중에 붙일 때 다시 짜므로, 이 단계는 넘침 없이 쓸 수 있는 정도까지만 한다. 실기기(휴대폰 + X-T5) 시험은 할 수 없으므로 USB 경로는 가짜 채널 시험으로, 화면·로그인·동기화는 에뮬레이터로 확인한다.

### 대상 기기: 갤럭시 S26 울트라
| 항목 | 값 | 이 계획에서 쓰는 곳 |
|---|---|---|
| 세로 논리 크기 | 약 412 × 915 dp (기본 화면 크기 설정) | 좁은 화면 시험의 기준 크기 |
| 화면 크기 설정을 키운 경우 | 폭 360 dp 안팎까지 줄어든다 | 시험 하한 |
| 가로 | 약 915 × 412 dp | 높이가 낮으므로 좁은 배치를 쓴다 |
| DeX(외부 모니터) | 창 폭 600 이상 | 넓은 배치(지금 macOS 모양)가 그대로 쓰인다 |
| 시스템 막대 | 가장자리까지 그리기(Android 15+), 제스처 막대 | `SafeArea`, 아래 탭이 아래 여백을 맡는다 |
| USB | USB-C, OTG 로 카메라에 전원 공급 | X-T5 와 C-to-C 케이블 |

dp 값은 화면 해상도와 기본 배율로 잡은 추정치다. 실제 값은 디자인 갤러리에 표시하는 화면 크기로 확인한다(Task C4).

## User Story
As X-T5 사용자, I want 휴대폰을 카메라에 케이블로 꽂고 묶음을 골라 7슬롯을 쓰기를, so that 노트북 없이 현장에서 장면에 맞는 레시피로 바꾼다.

## Problem → Solution
카메라 연결은 macOS `ImageCaptureCore` 에만 있고, 화면은 넓은 창(왼쪽 레일, 높이 140 로그)만 가정한다 → Android 에서 같은 `PtpTransport` 계약으로 연결하고, 좁은 화면에서는 아래 탭과 접히는 로그로 같은 흐름을 쓴다.

## Metadata
- **Complexity**: Large (새 플랫폼 채널 1, 전송 1, 반응형 셸)
- **Source PRD**: `Project/recipe-slot-manager/docs/prd.md`
- **PRD Phase**: 3. Android
- **Estimated Files**: 약 17개 (Dart 6, Kotlin 2, 설정 3, 시험 5, 문서 1)
- **대상 기기**: 갤럭시 S26 울트라 (화면은 임시 틀)
- **커밋 단위**: 작업 묶음 A–D 마다 하나 이상
- **선행 조건**: Android SDK 가 없다(`flutter doctor`: Unable to locate Android SDK). 묶음 A·C 는 SDK 없이 진행하고, 묶음 B·D 는 사용자가 Android Studio 를 설치한 뒤 진행한다

---

## UX Design

### Before
```
┌ 레일 ┬ [카메라 X-T5]        [동기화] [연결] ┐
│ 레시피│ 페이지                               │
│ 묶음  │                                     │
│ 원시값│ ─ 로그 (높이 140) ─                  │
└──────┴─────────────────────────────────────┘   S26 울트라(412 dp)에서는 넘친다
```

### After (S26 울트라 세로, 412 dp, 임시 틀)
```
┌ [카메라 X-T5]   [동기화] [연결] ┐  ← SafeArea 안
│ 페이지                          │
│                                 │
│ ▸ 마지막 로그 한 줄 (누르면 펼침)│
├ 레시피 │ 묶음 │ 원시 값 │ 디자인 ┤  ← NavigationBar
└─────────────────────────────────┘
```
폭 600 미만이거나 높이 500 미만(휴대폰 가로)이면 이 배치를 쓴다. 그 밖(DeX 창, 태블릿, macOS)은 지금 모양 그대로다. 색·간격은 기존 토큰만 쓰고 새 토큰이나 휴대폰 전용 컴포넌트는 만들지 않는다.

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| 탐색 | 왼쪽 레일 | 좁은 배치면 아래 `NavigationBar` | 같은 4개 목적지 |
| 로그 | 항상 140 높이 | 좁은 배치면 한 줄, 누르면 140 | 오류는 마지막 줄에 바로 보인다 |
| 휴대폰 가로 | - | 좁은 배치 그대로 | 높이 412 에 레일과 로그 140 이 들어가지 않는다 |
| 연결 | macOS 가 카메라를 찾음 | Android 가 USB 권한을 묻고 연결 | 거부하면 로그에 "권한 거부" |
| 카메라 꽂기 | - | X-T5 를 꽂으면 앱을 열지 묻는다(기본 앱 지정 시 권한도 기억) | `USB_DEVICE_ATTACHED` 필터 |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `lib/ptp/ptp_transport.dart` | all | 지켜야 할 계약: `connect`·`send`·`disconnect`, `PtpTransportException` |
| P0 | `lib/camera/macos_ptp_transport.dart` | all | 채널 이름 `recipe_slot_manager/ptp`, 오류 변환 `_invoke` |
| P0 | `macos/Runner/PtpChannel.swift` | all | 오류 코드(`connect`, `disconnected`, `busy`, `timeout`)와 시간 제한(연결 10초, 명령 5초) |
| P0 | `lib/ptp/ptp_container.dart` | all | 컨테이너 형식, `ptpResponseCode` |
| P1 | `lib/camera/fuji_camera.dart` | 25-35, 190-200 | `connect` 와 transaction ID 카운터 |
| P1 | `lib/ui/app_shell.dart` | all | 바꿀 셸 |
| P1 | `test/camera/macos_ptp_transport_test.dart` | all | 채널 가짜 처리기 시험 방식 |
| P1 | `test/support/test_app.dart` | 45-65 | `useLargeWindow`, `pumpShell` |
| P2 | `lib/ui/log_panel.dart`, `lib/ui/slots_page.dart:170-200` | - | 좁은 화면에서 손볼 곳 |

## External Documentation

| Topic | Source | Key Takeaway |
|---|---|---|
| USB host | developer.android.com/develop/connectivity/usb/host | `UsbManager.getDeviceList` → `requestPermission` → `openDevice` → `claimInterface` → `bulkTransfer` |
| PendingIntent | Android 12 (API 31) 변경 사항 | USB 권한 결과는 시스템이 extra 를 넣으므로 `FLAG_MUTABLE`. API 34 부터 mutable 은 명시적 intent(`setPackage`) 필요 |
| 브로드캐스트 등록 | Android 13 (API 33) | `ContextCompat.registerReceiver(..., RECEIVER_NOT_EXPORTED)` |
| PTP over USB | USB Still Image Capture Device Definition 1.0 | 명령(타입 1)·데이터(타입 2)는 bulk OUT, 데이터·응답(타입 3)은 bulk IN. 데이터 컨테이너는 명령과 같은 코드·transaction ID. 길이가 `maxPacketSize` 의 배수인 전송 뒤에는 0바이트 패킷 |
| PTP 세션 | ISO 15740 | `OpenSession(0x1002)` 은 transaction ID 0, 매개변수 세션 ID. 그 뒤 첫 명령의 transaction ID 는 1 |
| X-T5 연결 모드 | `docs/analysis.md:59` | 카메라 메뉴 `PC 연결 모드 → USB RAW 변환/백업 복원`, vendor ID `0x04CB`(1227) |

---

## Patterns to Mirror

### NAMING_CONVENTION
```dart
// SOURCE: lib/camera/macos_ptp_transport.dart:5-7
/// macOS `ImageCaptureCore` 로 PTP 명령을 보낸다. Swift 쪽은 `macos/Runner/PtpChannel.swift`.
class MacosPtpTransport implements PtpTransport {
  static const _channel = MethodChannel('recipe_slot_manager/ptp');
```
→ `AndroidPtpTransport`, Kotlin 쪽은 `android/app/src/main/kotlin/dev/supsuphae/recipe_slot_manager/PtpChannel.kt`.

### ERROR_HANDLING
```dart
// SOURCE: lib/camera/macos_ptp_transport.dart:37-48
  Future<T> _invoke<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw PtpTransportException(e.message ?? e.code);
    } on MissingPluginException {
      throw const PtpTransportException('이 플랫폼에는 카메라 연결 기능이 없다');
    } on FormatException catch (e) {
      throw PtpTransportException(e.message);
    }
  }
```
두 전송이 같은 이유로 바뀌므로 공용 함수로 옮긴다(Task A2). 플랫폼 오류 메시지는 한국어 평서문, Swift 와 같은 코드를 쓴다.

### LOGGING_PATTERN
전송 계층은 로그를 쓰지 않는다. 오류는 예외로 올리고 `CameraSession.run` 이 `CameraLog` 에 남긴다 (`lib/camera/camera_session.dart`).

### TEST_STRUCTURE
```dart
// SOURCE: test/camera/macos_ptp_transport_test.dart:7-22
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('recipe_slot_manager/ptp');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  ...
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
```
Android 전송 시험은 가짜 처리기가 bulk IN 패킷 목록을 차례로 돌려주게 한다.

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `lib/ptp/ptp_container.dart` | UPDATE | 데이터 컨테이너 만들기, 컨테이너 머리말 읽기 |
| `lib/camera/ptp_channel.dart` | CREATE | 채널 상수와 오류 변환(두 전송이 함께 씀) |
| `lib/camera/macos_ptp_transport.dart` | UPDATE | 공용 오류 변환 사용 |
| `lib/camera/android_ptp_transport.dart` | CREATE | USB bulk 위 PTP: 세션 열기, 명령·데이터 보내기, 응답 모으기 |
| `lib/camera/fuji_camera.dart` | UPDATE | 연결할 때마다 transaction ID 를 0 으로 |
| `lib/main.dart` | UPDATE | 플랫폼별 전송 선택 |
| `lib/ui/app_shell.dart` | UPDATE | 폭 600 미만 배치, SafeArea |
| `lib/ui/log_panel.dart` | UPDATE | 접힌 상태(한 줄) |
| `lib/ui/slots_page.dart` 등 | UPDATE | 휴대폰 크기 시험에서 넘치는 곳만 |
| `android/app/src/main/kotlin/.../PtpChannel.kt` | CREATE | `open`·`write`·`read`·`close` |
| `android/app/src/main/kotlin/.../MainActivity.kt` | UPDATE | 채널 등록 |
| `android/app/src/main/AndroidManifest.xml` | UPDATE | `usb.host` 기능, `INTERNET`, 꽂힘 intent 필터, 앱 이름 |
| `android/app/src/main/res/xml/device_filter.xml` | CREATE | vendor 1227 |
| `test/ptp/ptp_container_test.dart` | UPDATE | 데이터 컨테이너·머리말 |
| `test/camera/android_ptp_transport_test.dart` | CREATE | 세션 열기, 쪼개진 패킷, 오류 |
| `test/camera/fuji_camera_test.dart` | UPDATE | 다시 연결하면 transaction ID 1 부터 |
| `lib/ui/design_gallery_page.dart` | UPDATE | 지금 화면의 논리 크기 표시(S26 울트라 실제 dp 확인용) |
| `test/ui/compact_layout_test.dart` | CREATE | 412×915, 360×800, 915×412 에서 페이지마다 넘침 없음, 아래 탭 |
| `docs/prd.md`, `docs/analysis.md` | UPDATE | 단계 상태, Android 열린 질문 결과 |

## NOT Building

- GPS 장소별 레시피 기록 - 따로 스펙을 쓴다. 이 단계는 위치 권한·패키지를 넣지 않고, 셸에 목적지를 하드코딩해 막지도 않는다(목적지 목록 하나에서 레일과 탭을 모두 만든다)
- 휴대폰 화면의 완성된 디자인 - 이 단계는 임시 틀이다. 디자인 시스템 개편 때 다시 짠다
- iOS, 태블릿·폴더블·DeX 전용 배치 - 넓은 창은 지금 배치를 그대로 쓴다
- S Pen 전용 입력 - 터치와 같게 동작하면 충분하다
- 블루투스 연결 - 6·7단계
- 릴리스 서명·스토어 배포 - 디버그 APK 로 본인 휴대폰에 설치한다
- PTP 이벤트(interrupt 엔드포인트) - 슬롯 읽기·쓰기에 필요 없다
- 디자인 시스템 개편 - 나중 작업. 이 단계는 기존 토큰만 쓴다

---

## Step-by-Step Tasks

### 묶음 A: Android 전송 (Dart, SDK 불필요)

#### Task A1: 컨테이너 도우미 (TDD)
- **ACTION**: `ptp_container.dart` 에 두 함수 추가
- **IMPLEMENT**:
  - `Uint8List ptpDataContainer(Uint8List command, Uint8List payload)`: 길이 = 12 + payload, 타입 2, 코드·transaction ID 는 `command` 의 6-11 바이트를 그대로
  - `({int length, int type, int code}) ptpContainerHeader(Uint8List bytes)`: 12바이트 미만이면 `FormatException`
- **MIRROR**: `ptpCommand`·`ptpResponseCode` 의 `ByteData`, 리틀 엔디언
- **GOTCHA**: 데이터 컨테이너의 코드는 응답 코드가 아니라 **명령 코드**다
- **VALIDATE**: `flutter test test/ptp/ptp_container_test.dart`

#### Task A2: 채널 오류 변환 공용화
- **ACTION**: `MacosPtpTransport._invoke` 를 `lib/camera/ptp_channel.dart` 의 `const ptpChannel` 과 `Future<T> guardPtpChannel<T>(Future<T> Function())` 로 옮긴다
- **VALIDATE**: `macos_ptp_transport_test.dart` 가 고치지 않고 통과

#### Task A3: `AndroidPtpTransport` (TDD)
- **ACTION**: `lib/camera/android_ptp_transport.dart` 작성
- **IMPLEMENT**:
  - 채널 메서드(Kotlin 계약): `open` → `{'name': String}`, `write(bytes)` → null, `read()` → `Uint8List`(bulk IN 한 번의 결과), `close` → null
  - `connect()`: `open` → `OpenSession`(transaction ID 0, 매개변수 1) 을 `_transact` 로 보내고, 응답이 `ok` 또는 `sessionAlreadyOpen` 이 아니면 `close` 뒤 `PtpTransportException`
  - `send(command, {data})`: `write(command)` → `data` 가 있으면 `write(ptpDataContainer(command, data))` → `read` 를 반복해 컨테이너를 모은다. 첫 패킷의 머리말 길이만큼 이어 붙이고, 타입 2 면 payload 를 모으고 타입 3 이면 끝낸다. `PtpReply(code, payload)`
  - 응답 컨테이너가 끝내 오지 않는 경우는 Kotlin 의 bulk 시간 제한(5초)이 `timeout` 오류로 끝낸다
  - `disconnect()`: `CloseSession` 을 보내 보고 실패는 무시, 이어서 `close`
- **MIRROR**: `MacosPtpTransport` 구조, `guardPtpChannel`
- **GOTCHA**:
  - 한 번의 `read` 에 데이터 컨테이너와 응답 컨테이너가 함께 들어올 수 있다. 남은 바이트를 버리지 말고 다음 컨테이너로 넘긴다
  - 반대로 컨테이너 하나가 여러 `read` 로 쪼개져 올 수 있다
- **VALIDATE**: `test/camera/android_ptp_transport_test.dart`
  - OpenSession 이 transaction ID 0, 매개변수 1 로 나간다
  - 값 읽기: 데이터(2바이트)와 응답이 한 패킷 / 두 패킷 / 데이터가 세 패킷으로 쪼개짐 → 모두 같은 `PtpReply`
  - 값 쓰기: `write` 두 번(명령, 데이터 컨테이너), 데이터 컨테이너의 코드·transaction ID 가 명령과 같다
  - 응답 코드 `sessionAlreadyOpen` 이면 연결 성공, 그 밖의 실패면 `close` 호출 뒤 예외
  - 타입이 2·3 이 아닌 컨테이너, 머리말보다 짧은 패킷 → `PtpTransportException`

#### Task A4: 연결마다 transaction ID 초기화 (TDD)
- **ACTION**: `FujiCamera.connect` 에서 `_transactionId = 0`
- **GOTCHA**: macOS 에도 적용된다. `ImageCaptureCore` 가 세션을 새로 열 때도 PTP 규칙상 1 부터가 맞다. 실기기 미확인으로 기록
- **VALIDATE**: `fuji_camera_test.dart` 에 "다시 연결하면 첫 명령의 transaction ID 가 1" 시험

#### Task A5: 플랫폼별 전송 선택
- **ACTION**: `main.dart` 에서 `Platform.isAndroid ? AndroidPtpTransport() : MacosPtpTransport()`
- **VALIDATE**: `flutter analyze`, `flutter build macos --debug --dart-define-from-file=supabase.example.json`

### 묶음 B: Kotlin USB 채널 (SDK 필요)

#### Task B1: `PtpChannel.kt`
- **ACTION**: Swift `PtpChannel` 과 같은 역할의 Kotlin 클래스
- **IMPLEMENT**:
  - 모든 USB 작업은 단일 스레드 executor 에서 하고 결과는 메인 스레드에서 `result` 로 돌려준다. 한 번에 하나만 돌므로 `busy` 처리가 필요 없다
  - `open`: `getDeviceList` 에서 `vendorId == 0x04CB` 이고 인터페이스 클래스가 `USB_CLASS_STILL_IMAGE` 인 장치 → 권한 없으면 `requestPermission`(PendingIntent `FLAG_MUTABLE`, `setPackage`, 리시버 `RECEIVER_NOT_EXPORTED`) → `openDevice` → `claimInterface(iface, true)` → bulk IN/OUT 엔드포인트 저장 → `device.productName ?: "Fujifilm"`
  - `write`: `bulkTransfer(out, bytes, len, 5000)`, 길이가 `maxPacketSize` 배수면 0바이트 전송을 한 번 더
  - `read`: `ByteArray(64 * 1024)` 로 `bulkTransfer(in, ..., 5000)`, 음수면 `timeout`
  - `close`: `releaseInterface`, `close`
  - 장치가 분리되면(`ACTION_USB_DEVICE_DETACHED`) 연결을 정리한다
  - 오류 코드·메시지는 Swift 와 같은 말: `connect`("후지필름 카메라를 찾지 못했다. USB 연결과 PC 연결 모드를 확인할 것"), `permission`("USB 권한이 거부됐다"), `disconnected`, `timeout`
- **GOTCHA**: Android 의 기본 MTP 처리가 카메라를 먼저 잡을 수 있다. `claimInterface(force = true)` 로 커널 드라이버를 떼어 낸다. 다른 앱이 잡고 있으면 실패하므로 그 메시지를 로그로 보인다
- **VALIDATE**: `flutter build apk --debug`

#### Task B2: 등록과 매니페스트
- **ACTION**: `MainActivity.configureFlutterEngine` 에서 채널 등록. 매니페스트에 `<uses-feature android:name="android.hardware.usb.host" android:required="true"/>`, `INTERNET` 권한, `USB_DEVICE_ATTACHED` intent 필터 + `@xml/device_filter`(vendor-id 1227), `android:label="Recipe Slot Manager"`
- **GOTCHA**: `INTERNET` 은 debug 매니페스트에만 있어 release 빌드에서 Supabase 가 막힌다
- **VALIDATE**: `flutter build apk --debug`, 에뮬레이터 설치 후 실행

### 묶음 C: 좁은 화면 (Dart, SDK 불필요)

이 묶음은 임시 틀이다. 넘침을 없애고 손가락으로 쓸 수 있게 하는 데서 멈춘다.

#### Task C1: 휴대폰 크기 시험 먼저 (RED)
- **ACTION**: `test/ui/compact_layout_test.dart`. 크기 세 개(412×915 S26 울트라 세로, 360×800 화면 크기를 키운 경우, 915×412 가로)마다 셸의 네 목적지와 레시피 편집·묶음 편집·비교 화면을 띄운다. `devicePixelRatio = 1` 로 논리 크기를 그대로 준다
- **VALIDATE**: 넘침 예외 없음, `NavigationBar` 가 보이고 `NavigationRail` 이 없음. 처음에는 실패해야 한다

#### Task C2: 반응형 셸과 로그
- **IMPLEMENT**:
  - 목적지 목록 하나(`(icon, label)`)에서 레일과 아래 탭을 모두 만든다. 폭 < 600 또는 높이 < 500 이면 아래 탭
  - 본문을 `SafeArea` 로 감싼다. 아래 여백은 `NavigationBar` 가 맡으므로 아래 탭일 때는 `bottom: false`
  - `LogPanel(compact: true)`: 마지막 줄만, 누르면 140 으로 펼침
- **VALIDATE**: C1 시험 통과, 기존 1800×1400 시험 그대로 통과

#### Task C3: 넘치는 화면 손보기
- **ACTION**: C1 에서 실패한 곳만 고친다. 예상: `CameraBar`(모델 이름을 `Flexible` + 말줄임), `SlotsPage` 의 `DataTable`(가로 스크롤)
- **VALIDATE**: `flutter test`

#### Task C4: 화면 크기 표시
- **ACTION**: 디자인 갤러리 맨 위에 `MediaQuery.sizeOf(context)` 와 `devicePixelRatio` 를 한 줄로 보인다
- **VALIDATE**: 위젯 시험 하나. S26 울트라에서 이 값으로 위 표의 추정치를 고친다

### 묶음 D: 확인과 문서 (SDK 필요)

#### Task D1: 에뮬레이터 확인
- S26 울트라에 가까운 AVD: 1440×3120, 밀도 560 (약 411 dp 폭). Android Studio 기본 프로필로는 Pixel 9 Pro XL 이 비슷하다
- 에뮬레이터에서 `flutter run -d <id> --dart-define-from-file=supabase.json`
- 세로·가로를 돌려 보고 디자인 갤러리의 화면 크기를 기록한다
- 로그인 → 레시피 저장 → 동기화 → macOS 에서 같은 레시피가 보인다
- 연결 → "후지필름 카메라를 찾지 못했다" 가 로그에 남는다(에뮬레이터에는 USB 장치가 없다)

#### Task D2: 문서
- `prd.md`: 3단계 상태, 결정 기록(Dart 에서 USB 컨테이너 조립, 폭 600 기준)
- `analysis.md`: Android 열린 질문(권한·전원)에 구현한 처리와 미확인 항목

---

## Testing Strategy

### Unit Tests

| Test | Input | Expected Output | Edge Case? |
|---|---|---|---|
| 데이터 컨테이너 | 명령(코드 0x1016, tid 7), payload 2바이트 | 길이 14, 타입 2, 코드 0x1016, tid 7 | |
| 머리말 | 11바이트 | `FormatException` | ✓ |
| 세션 열기 | `connect` | 첫 `write` 가 OpenSession tid 0, 매개변수 1 | |
| 세션 이미 열림 | 응답 0x201E | 연결 성공 | ✓ |
| 묶여 온 컨테이너 | 데이터+응답이 한 `read` | 데이터와 코드 모두 | ✓ |
| 쪼개진 컨테이너 | 데이터가 세 `read` | 이어 붙인 payload | ✓ |
| 쓰기 | `send(cmd, data)` | `write` 2번, tid 일치 | |
| 알 수 없는 타입 | 타입 4 | `PtpTransportException` | ✓ |
| 플랫폼 오류 | `PlatformException('permission')` | 메시지 그대로 `PtpTransportException` | ✓ |
| 다시 연결 | connect → 명령 → connect → 명령 | 두 번째 첫 명령 tid 1 | ✓ |
| 412×915, 360×800, 915×412 | 네 목적지 + 편집·비교 | 넘침 없음, 아래 탭 | ✓ |
| 1800×1400 | 기존 시험 | 레일 배치 그대로 | |

### Edge Cases Checklist
- [x] 빈 응답·짧은 패킷
- [x] 컨테이너가 패킷 경계와 어긋남
- [ ] 동시 명령 - Kotlin 단일 스레드 executor 가 순서를 지킨다(시험 불가, 코드로 보장)
- [x] 권한 거부 - 플랫폼 오류 변환으로 확인
- [ ] 케이블 분리 중 쓰기 - 실기기 필요

---

## Validation Commands

```bash
cd Project/recipe-slot-manager
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
flutter build macos --debug --dart-define-from-file=supabase.example.json
flutter build apk --debug --dart-define-from-file=supabase.example.json   # 묶음 B 부터
```
EXPECT: 문제 없음, 전부 통과(Skipped 0), 두 빌드 성공

### Manual Validation
- [ ] 에뮬레이터(S26 울트라 크기): 아래 탭, 가로 회전, 로그 펼침, 로그인·동기화
- [ ] S26 울트라 실기기(카메라 없이): 앱 설치, 디자인 갤러리의 화면 크기 기록
- [ ] 에뮬레이터: 연결 시 카메라 없음 오류가 로그에 남음
- [ ] (실기기, 미확인으로 남김) 휴대폰 + X-T5: 권한 대화상자 → 7슬롯 읽기 → 묶음 쓰기 30초 안

---

## Acceptance Criteria
- [ ] 묶음 A–D 의 작업 완료
- [ ] 검증 명령 전부 통과
- [ ] 412×915, 360×800, 915×412 에서 모든 화면에 넘침 없음
- [ ] macOS 동작과 기존 시험 그대로

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Android SDK 설치 전에는 Kotlin 을 빌드할 수 없음 | 높음 | 중 | 묶음 A·C 먼저. 설치 뒤 B·D |
| 기본 MTP 처리가 카메라 인터페이스를 잡음 | 중 | 높음 | `claimInterface(force)`, 실패 메시지를 로그에. 실기기 미확인 |
| 휴대폰 전원(OTG)으로 카메라가 연결 모드에 들어가지 않음 | 중 | 높음 | 문서에 열린 질문으로 남김 |
| transaction ID 초기화가 macOS 실기기에서 다르게 동작 | 낮음 | 중 | PTP 규칙대로, 실기기 미확인 기록 |
| 에뮬레이터로는 USB 경로를 확인할 수 없음 | 확실 | 중 | 가짜 채널 시험으로 컨테이너 처리를 덮는다 |
| S26 울트라의 실제 dp 가 추정과 다름 | 중 | 낮음 | 360 하한까지 시험하고, 갤러리 표시값으로 표를 고친다 |
| 삼성 기본 앱이 카메라를 먼저 잡음(사진 가져오기 알림) | 중 | 높음 | 알림을 닫거나 기본 앱을 이 앱으로 지정. 실기기 미확인으로 기록 |

## Notes
- USB 컨테이너 조립을 Kotlin 이 아니라 Dart 에 둔다. Kotlin 은 바이트를 그대로 옮기기만 해서 실기기 없이도 PTP 처리 전부를 시험할 수 있다. macOS 는 `ImageCaptureCore` 가 컨테이너를 대신 다루므로 이 경로를 쓰지 않는다
- 범용 USB 플러그인(`quick_usb` 등)은 쓰지 않는다. 필요한 것은 bulk 전송 두 개와 권한뿐이라 Kotlin 한 파일이 더 작다

## 구현 중 바뀐 점
- Task C3: 폭 412·360 에서 화면 단위로는 넘침이 없었다. 디자인 화면을 끝까지 내리는 시험을 더하자 `ChangeRow` 가 긴 값(필름 시뮬레이션 이름)에서 37px 넘쳤다. 이름과 값을 말줄임으로 줄이도록 고쳤다. 목록은 보이는 줄만 그리므로 넘침 시험은 화면을 끝까지 내려야 한다
- 시험 도우미 `TestApp.useLargeWindow` 를 크기를 받는 `useWindow` 로 바꾸고, `pumpShell` 에 `headerActions` 를 더했다
- 리뷰 반영: Android 전송은 응답의 transaction ID 를 확인해 시간이 초과된 앞 명령의 늦은 응답을 건너뛰고, 세션을 여는 중 어떤 오류가 나도 장치를 닫는다. `ChangeRow` 는 값 하나가 줄 폭의 30% 를 넘지 않게 해 넓은 화면에서 값이 오른쪽 끝에 붙는다. 접힌 로그 높이는 터치 최소 크기 48 이다
- 리뷰 LOW 반영: 셸 본문을 레일·아래 탭과 상관없이 같은 자리에 두어 배치가 바뀌어도 화면 상태가 남고, Android 전송은 연결·명령·끊기를 `SerialQueue` 로 하나씩 한다. 같은 도우미로 `LibraryStore` 의 파일 쓰기도 하나씩 하게 고쳤다(동시 저장 때 앞의 내용이 뒤 저장을 덮던 경합)
- Task D1: 새 AVD 대신 기본 `Medium Phone API 37.0`(1080×2400, 420 dpi)을 썼다. 갤러리 표시값 세로 411 × 914 dp, 가로 914 × 411 dp 로 S26 울트라 추정치와 같다. 연결을 누르면 Kotlin 채널을 거쳐 "후지필름 카메라를 찾지 못했다" 가 접힌 로그에 남는다. 로그인·동기화는 사용자 계정이 필요해 확인하지 않았다
