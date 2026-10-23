# Community for Fuji 1.9.10 분석

대상: `/Applications/Community for Fuji.app` (Mac App Store, `co.fujicommunity.app`, build 34, macOS 13+)
방법: 번들 구성, Info.plist, Dart AOT 문자열의 `package:` 경로, 네이티브 플러그인의 링크 프레임워크와 문자열. 코드 실행·디컴파일·네트워크 관찰은 하지 않았다.

## 기술 스택

| 층 | 사용 기술 |
|---|---|
| UI | Flutter (macOS 데스크톱), GetX(`package:get`) 라우팅·DI·상태 |
| 구조 | 3개 패키지: `fuji_community_app`(화면), `fuji_framework`(도메인·데이터, Clean Architecture), `fuji_design_system`(컴포넌트) |
| 백엔드 | Supabase (`gotrue` 인증, `postgrest` DB, `storage_client` 사진, `realtime_client`) |
| 로그인 | Google Sign-In, Sign in with Apple |
| 푸시·분석 | Firebase Messaging, Firebase Analytics |
| 결제 | StoreKit 인앱결제 (Pro 구독, paywall) |
| 로컬 저장 | sqflite, shared_preferences, flutter_secure_storage |
| 기타 | flutter_map(국가 지도), lottie, cached_network_image, exif, image, emoji_picker |
| 네이티브 | `fuji_camera_kit`: CoreBluetooth + ImageCaptureCore(PTP)로 카메라 레시피 슬롯 읽기/쓰기. `fuji_ocr_kit`: Vision 텍스트 인식으로 레시피 사진 스캔 |

## 기능 지도 (`features/*`)

**커뮤니티 핵심**
- recipes / recipe_detail: 필름 시뮬레이션 레시피 목록·필터·상세, 다이얼 값 표시, 사진 캐러셀, 댓글
- publish: 레시피 작성(다이얼 입력, 옵션 피커), 중복 레시피 감지, 사진·OCR 스캔으로 입력
- activity: 피드, 크리에이터 레일
- likes / follows / public_profile / authors: 사진 좋아요, 팔로우, 작성자 페이지
- collections: 레시피 모음(아이콘 지정, 키트를 모음으로)
- communities: 세계 지도 위 국가별 커뮤니티, 국가 멤버·사진
- rankings, achievement 배지, rank 배지
- notifications: 알림함, 벨 배지, 푸시
- safety: 신고, 차단

**카메라 연동 (차별 기능)**
- my_camera: 블루투스/USB로 카메라 연결, 커스텀 슬롯 읽기·쓰기, 레시피 설치
- loadout: 슬롯 묶음 저장·복원, 카메라 설정 백업/복원
- darkroom: RAF(RAW) 파일에 레시피를 적용해 현상, 분할 비교 뷰
- diagnostics: 연결 진단·리포트 전송

**운영**
- auth, welcome/onboarding tour, splash, settings, 언어 선택(i18n), 강제 업데이트(`app_versions`), 릴리스 노트, Pro 구독

## 데이터 모델 (바이너리 문자열에서 추린 테이블·컬럼 이름)

- `profiles` (followers_count, following_count, recipes_count, photos_count)
- `recipes` (author_id, film_simulation_id, category_id, featured_at, likes/saves/installs/comments_count, tested_light_count)
- `recipe_photos` (recipe_id, taken_at), `photo_likes` (photo_id, user_id)
- `recipe_comments`, `recipe_installs`, 저장한 레시피
- `follows` (follower_id, followed_id), `blocks` (blocked_id), 신고(reporter_id, content_id)
- `collections` (owner_id), 컬렉션 항목
- `notifications` (actor_id, actor_count, event_id, read_at), `push_tokens`
- 카탈로그: `cameras` (generation_id), `categories`, 필름 시뮬레이션
- `app_versions` (min_generation_id 등 강제 업데이트 기준)
- RPC 인자 접두사 `p_*` (p_recipe_id, p_before_id 커서 페이지네이션 등) → Postgres 함수 다수 사용

## X-T5 카메라 슬롯 프로토콜 (공개 자료 기준)

출처: [eggricesoy/filmkit](https://github.com/eggricesoy/filmkit) (MIT, X100VI에서 확인, X-T5는 미확인). rawji, fudge, libgphoto2와 X RAW Studio의 USB 캡처를 바탕으로 정리된 자료다.

- 연결: USB 케이블. 카메라 메뉴 `PC 연결 모드 → USB RAW 변환/백업 복원`. USB vendor ID `0x04CB`.
- 명령: 표준 PTP만 쓴다. `OpenSession 0x1002`, `GetDevicePropValue 0x1015`, `SetDevicePropValue 0x1016`, `CloseSession 0x1003`.
- 슬롯: `0xD18C`에 1–7을 쓰면 C1–C7 중 하나가 선택된다. 앱이 슬롯 수를 제한하지 않는 한 7개 모두 접근된다.
- 이름: `0xD18D` (PTP 문자열)
- 레시피 값 `0xD18E–0xD1A5`

| 속성 | 의미 | 속성 | 의미 |
|---|---|---|---|
| D190 | 다이내믹 레인지 % | D199 | 화이트밸런스 모드 |
| D192 | 필름 시뮬레이션 | D19A / D19B | WB 시프트 R / B |
| D193 / D194 | 모노 WC / MG ×10 | D19C | 색온도(K) |
| D195 | 그레인 | D19D / D19E | 하이라이트 / 섀도 ×10 |
| D196 | 컬러 크롬 | D19F | 컬러 ×10 |
| D197 | 컬러 크롬 FX 블루 | D1A0 | 샤프니스 ×10 |
| D198 | 스무스 스킨 | D1A1 | 고감도 NR (비선형 인코딩) |
| D18E / D18F | 이미지 크기 / 화질 | D1A2 | 클래리티 ×10 |

- 필름 시뮬레이션 값: Provia 0x01 … Classic Chrome 0x0B, Eterna 0x10, Classic Neg 0x11, Nostalgic Neg 0x13, Reala Ace 0x14 (X-T5에서 값 확인 필요)
- 제약: 색온도는 WB가 색온도 모드일 때만 쓰인다. 흑백 시뮬레이션은 컬러 값을 거부한다.
- RAF 현상(darkroom)도 같은 연결에서 가능하다: RAF 업로드 → `0xD185` 프로필 수정 → `0xD183`로 변환 → JPEG 회수. 현상은 카메라 프로세서가 한다.

Community for Fuji의 `fuji_camera_kit`도 macOS `ImageCaptureCore`의 `requestSendPTPCommand`로 같은 경로를 쓴다(링크 프레임워크와 문자열로 확인). BLE는 무선 연결용으로 별도다.

### Flutter에서 쓰는 경로

| 플랫폼 | 방법 |
|---|---|
| macOS | Swift 플랫폼 채널 + `ImageCaptureCore` `ICCameraDevice.requestSendPTPCommand` |
| iOS / iPadOS | 같은 `ImageCaptureCore` API (USB-C 연결) |
| Android | Kotlin 플랫폼 채널 + `UsbManager` bulk 전송 |

## 만들 때 범위 판단

| 범위 | 작업량 | 비고 |
|---|---|---|
| A. 레시피 커뮤니티 MVP (목록·상세·작성·좋아요·댓글·프로필·팔로우) | 1–2주 | Supabase 스키마 + 앱 화면 |
| B. A + 컬렉션·알림·국가 지도·랭킹·신고/차단 | +1–2주 | |
| C. 카메라 슬롯 C1–C7 읽기/쓰기 (USB PTP) | 1–2주 | 프로토콜은 공개됨. X-T5 실기기로 값 확인 필요 |
| D. RAF 현상(darkroom) | 1–2주 | 카메라 내부 변환을 쓰므로 RAW 엔진 불필요 |
| E. 무선(BLE) 연결 | 부분 가능 | 전체 설정 백업을 고쳐 복원하는 방식. `bluetooth-research.md` |

## 지켜야 할 선

- 원본 앱의 코드·에셋·아이콘·문구·이름을 가져오지 않는다. 기능 구조만 참고하고 구현은 새로 한다.
- 원본 앱의 Supabase/Firebase 프로젝트, 키, 엔드포인트는 사용하지 않는다. 자체 백엔드를 만든다.
- "Fuji" / "Fujifilm" 상표를 앱 이름에 쓰는 것은 배포 시 문제가 될 수 있다.
