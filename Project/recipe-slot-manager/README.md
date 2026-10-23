# Recipe Slot Manager

후지필름 X-T5의 사용자 설정 슬롯 C1–C7을 USB(PTP)로 읽고 쓰는 본인용 앱이다. 레시피 보관함과 사진 기록도 함께 다룬다. macOS와 Android에서 돈다.

## 화면

| 탭 | 하는 일 |
|---|---|
| 레시피 | 레시피(필름 시뮬레이션과 값) 만들기·고치기. 카메라 슬롯, 후지 JPEG 의 EXIF, 레시피 사진(OCR)에서 가져오기 |
| 세트 | C1–C7에 넣을 레시피 7개 묶음. 카메라의 현재 슬롯과 비교한 뒤 한 번에 저장하고, 저장 전에 자동으로 백업한다 |
| 사용자 설정 | 카메라의 C1–C7을 읽고 슬롯 하나씩 쓰기, 백업에서 되돌리기 |
| RAW 미리보기 | RAF 를 카메라로 보내 카메라 안에서 현상한 결과를 레시피끼리 나란히 보기 |
| 사진 | 지정한 폴더의 사진을 색인해 촬영 시각·장소·필름 시뮬레이션으로 찾기(목록·지도), 세트를 저장한 위치 기록 |

Supabase 설정이 있으면 로그인해 레시피·세트·사진 색인·세트 저장 기록을 기기 사이에 동기화한다(사진 파일은 올리지 않는다). 없으면 기기에만 저장한다.

## 실행

Flutter(Dart SDK 3.13 이상)가 필요하다.

```bash
flutter pub get
flutter run -d macos
```

Android 는 `flutter run -d <기기 id>` 로 실행한다.

카메라를 연결하기 전에 카메라 메뉴에서 `PC 연결 모드 → USB RAW 변환/백업 복원` 을 고른다. macOS 에서는 사진 앱과 이미지 캡처를 닫는다(카메라를 먼저 잡는다).

### Supabase 동기화 (선택)

1. Supabase 프로젝트의 SQL 편집기에서 `supabase/setup.sql`(레시피·세트)과 `supabase/photo-log.sql`(사진 색인·세트 저장 기록)을 차례로 실행한다(테이블, 권한, RLS)
2. `supabase.example.json` 을 `supabase.json` 으로 복사하고 프로젝트 URL 과 publishable key 를 넣는다. 이 파일은 저장소에 올리지 않는다
3. `flutter run -d macos --dart-define-from-file=supabase.json`

secret 키나 service_role 키는 넣지 않는다.

## 검사

```bash
flutter analyze
dart format --set-exit-if-changed lib test tool
flutter test
```

## 문서

| 문서 | 내용 |
|---|---|
| `docs/prd.md` | 슬롯 관리 요구사항과 단계 |
| `docs/photo-log.prd.md` | 사진 기록 요구사항과 단계 |
| `docs/plans/` | 단계별 구현 계획과 구현 중 바뀐 점 |
| `docs/unverified.md` | 실제 카메라·기기로 아직 확인하지 못한 항목 |
| `docs/analysis.md` | 참고한 앱(Community for Fuji) 분석 |
