# 레시피 슬롯 매니저 (가칭)

## Problem Statement

X-T5로 장소를 옮겨 다니며 찍을 때, 장면에 맞는 필름 레시피로 바꾸려면 카메라 메뉴에서 값 20여 개를 손으로 입력해야 한다. 메뉴에서는 값 하나를 바꿨을 때 결과가 어떻게 달라지는지 보이지 않고, 지금 쓰는 앱은 무료로 슬롯 3개만 다룬다. 그 결과 현장에서 레시피 교체를 포기하거나, 맞지 않는 레시피로 찍게 된다.

## Evidence

- 사용자 본인의 관찰: 메뉴에서 값 20개를 손으로 입력, 무료 앱은 슬롯 3개만 사용, 값을 바꿨을 때 무엇이 바뀌는지 모름
- 경쟁 앱 모두 여러 레시피 일괄 전송을 유료로 묶었다: Community for Fuji(C4–C7 Pro), Fuji X Weekly 앱(레시피 세트 Patron 전용)
- 카메라 자체는 C1–C7 슬롯 7개를 모두 표준 PTP 속성으로 노출한다 (FilmKit 프로토콜 문서, `analysis.md`)

## Proposed Solution

본인용 Flutter 앱. X-T5에 USB로 연결해 C1–C7을 읽고, 미리 정한 상황별 7개 묶음을 한 번에 덮어쓴다. 덮어쓰기 전에 현재 슬롯을 자동 백업하고, 바뀌는 값을 슬롯별로 나란히 보여 준다. 레시피는 Supabase에 저장하고 기기에 캐시해 현장에서 오프라인으로도 쓴다. macOS에서 연결 기반을 검증한 뒤 현장용 Android로 옮긴다. 카메라와의 통신은 공개된 표준 PTP 명령만 쓰고 펌웨어는 건드리지 않는다.

## Key Hypothesis

We believe 상황별 7슬롯 묶음의 일괄 덮어쓰기와 변경 비교 화면이 카메라 메뉴 수동 입력을 대체할 것이다 for 장소를 옮기며 찍는 X-T5 사용자(본인).
We'll know we're right when 7슬롯 전체 덮어쓰기가 10초 안에 끝나고, 촬영 중 카메라 메뉴에서 레시피 값을 손으로 바꾸는 일이 없어질 때.

## What We're NOT Building

- 커뮤니티 기능(다른 사용자와 레시피 공유, 피드, 좋아요, 팔로우) - 본인용 앱이다
- 동영상 레시피 - X-T5 사진 슬롯만 다룬다
- 다른 앱의 결제 잠금 우회 - 자체 구현으로 7슬롯을 직접 다룬다
- 다른 카메라 기종 공식 지원 - X-T5만 확인한다 (구조는 기종 확장을 막지 않게 둔다)
- ISO·노출 보정 전송 - 프로토콜 범위 밖이다

## Success Metrics

| Metric | Target | How Measured |
|--------|--------|--------------|
| 7슬롯 전체 덮어쓰기 시간 | 10초 이내 | 앱 내부 타이머 (연결된 상태에서 쓰기 시작 → 검증 읽기 끝) |
| 현장 레시피 교체 시간 | 앱 실행부터 30초 이내 | 직접 측정 (앱 열기 → 묶음 선택 → 쓰기 완료) |
| 쓰기 후 검증 불일치 | 0건 | 쓴 값과 다시 읽은 값 비교 로그 |
| 백업 없이 덮어쓴 횟수 | 0건 | 쓰기마다 백업 기록 존재 여부 |

## Open Questions

- [ ] X-T5의 속성 코드·값 인코딩이 FilmKit(X100VI 기준)과 같은가 - 1단계에서 실기기로 확인
- [ ] 슬롯 1개 쓰기에 PTP 왕복이 몇 번, 몇 ms 걸리는가 - 10초 목표 달성 여부를 결정한다. 바뀐 값만 쓰면 왕복 수가 줄어든다
- [ ] 슬롯 선택 `0xD18C`이 카메라의 현재 촬영 설정까지 바꾸는가
- [ ] Android에서 USB PTP 연결 시 권한·전원 조건 (USB OTG, 카메라 연결 모드)
- [ ] 블루투스로 슬롯을 쓰는 방법 - 공개 자료가 없다. 7단계 조사 결과에 따라 범위가 정해진다
- [ ] 후지 JPEG EXIF(MakerNote)에 레시피 값이 어디까지 기록되는가 (DR, 클래리티, WB 시프트 등)
- [ ] 다이내믹 레인지(ISO 의존), 클래리티(드라이브 모드 의존)를 카메라가 거부할 때의 처리 방식

---

## Users & Context

**Primary User**
- **Who**: X-T5를 들고 여러 장소를 옮겨 다니며 찍는 사진가(본인)
- **Current behavior**: 카메라 메뉴에서 레시피 값을 손으로 입력하거나, 무료 앱으로 슬롯 3개만 관리한다
- **Trigger**: 장소를 옮기거나 특정 장면(야간, 실내, 역광 등)을 만나 지금 슬롯에 맞는 레시피가 없을 때
- **Success state**: 휴대폰에서 묶음 하나를 고르면 몇 초 뒤 C1–C7이 그 장면용 레시피로 바뀌어 있다

**Job to Be Done**
When 장소를 옮기거나 특정 장면을 만나면, I want to 그 상황에 맞는 레시피 7개를 카메라에 한 번에 넣고, so I can 메뉴를 만지지 않고 바로 찍을 수 있다.

**Non-Users**
다른 후지 사용자, 레시피를 공유·발견하려는 사람. 배포와 다른 기종 지원은 고려하지 않는다.

---

## Solution Detail

### Core Capabilities (MoSCoW)

| Priority | Capability | Rationale |
|----------|------------|-----------|
| Must | USB로 C1–C7 읽기·쓰기 | 앱의 존재 이유 |
| Must | 덮어쓰기 전 7슬롯 자동 백업, 한 번에 복원 | 쓰기 실패나 잘못된 값으로부터 기존 레시피를 지킨다 |
| Must | 쓴 뒤 다시 읽어 검증 | 카메라가 값을 거부했는지 알려면 필요하다 |
| Must | 레시피 보관함 (작성·편집·태그) | 슬롯에 넣을 재료 |
| Must | 상황별 묶음 (슬롯 1–7에 레시피 배정) + 일괄 덮어쓰기 | 핵심 가설 |
| Must | 바꾸기 전 비교 (슬롯별 현재 값 vs 쓸 값, 바뀌는 항목 강조) | "무엇이 바뀌는지 모름" 해결 |
| Must | Supabase 로그인·저장 + 기기 캐시 | 사용자 선택(처음부터 클라우드). 현장 오프라인 대비로 캐시 필요 |
| Must | Android 실행 | 현장 사용 |
| Should | 카메라 슬롯을 보관함으로 가져오기 | 손으로 만든 기존 레시피 관리 |
| Should | 후지 JPEG EXIF에서 레시피 추출 | 예전 사진 설정 되살리기 |
| Should | 스크린샷·사진 OCR로 레시피 입력 | 웹·SNS 레시피 가져오기 |
| Should | 내 RAF로 미리보기 (카메라 내부 현상, 좌우 비교) | 값 변화의 결과를 눈으로 확인 |
| Could | 블루투스 연결 | 케이블 없이 교체. 공개 자료 부족으로 조사 결과에 달림 |
| Won't | 커뮤니티 공유, 동영상 레시피, 다른 기종 | 본인용, X-T5 사진 슬롯 한정 |

### MVP Scope

1–3단계. macOS와 Android에서 X-T5에 연결해, 보관함의 레시피로 상황별 묶음을 만들고, 비교 화면을 본 뒤, 자동 백업과 함께 7슬롯을 한 번에 덮어쓴다.

### User Flow

1. 앱을 연다 (로그인 상태 유지, 캐시된 묶음 표시)
2. X-T5를 USB로 연결한다 → 앱이 C1–C7 현재 값을 읽는다
3. 장면에 맞는 묶음을 고른다 (예: "야간 거리")
4. 슬롯별 비교 화면에서 바뀌는 값을 확인한다
5. "쓰기"를 누른다 → 자동 백업 → 바뀐 값만 쓰기 → 다시 읽어 검증 → 결과 표시

---

## Technical Approach

**Feasibility**: HIGH (USB), LOW (블루투스)

**Architecture Notes**
- 카메라 통신: 공개 표준 PTP 명령 `OpenSession 0x1002`, `GetDevicePropValue 0x1015`, `SetDevicePropValue 0x1016`. 슬롯 선택 `0xD18C`(1–7), 이름 `0xD18D`, 레시피 값 `0xD18E–0xD1A5`. 출처는 FilmKit(MIT) 문서와 `analysis.md`
- 플랫폼 채널: macOS는 Swift + `ImageCaptureCore` `ICCameraDevice.requestSendPTPCommand`, Android는 Kotlin + `UsbManager` bulk 전송. PTP 컨테이너 조립·해석은 Dart 한 곳에 두고, 네이티브 쪽은 바이트 송수신만 맡는다
- 레시피 모델은 카메라 속성 값과 화면 표시 값(예: 하이라이트 +1.5 ↔ 15)을 변환하는 계층을 하나 둔다. 비교 화면, 검증, EXIF·OCR 가져오기가 모두 이 모델을 쓴다
- 저장: Supabase(Postgres + Auth)가 원본, 기기 JSON 파일이 사본. 현장에서는 기기 사본으로 동작하고 연결되면 동기화한다
- 쓰기는 바뀐 속성만 보낸다. 10초 목표와 비교 화면이 같은 diff를 쓴다

**Technical Risks**

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| X-T5 속성 코드·인코딩이 X100VI 기준 자료와 다름 | M | 1단계에서 실기기로 7슬롯 전체를 읽어 값 표를 만든다 |
| 7슬롯 쓰기가 10초를 넘음 | M | 바뀐 값만 쓰기, 1단계에서 왕복 시간 측정 |
| 카메라가 DR·클래리티 등 값을 거부 | M | 쓴 뒤 다시 읽어 불일치 항목을 표시 |
| 쓰는 도중 케이블 분리로 슬롯 일부만 변경 | L | 쓰기 전 자동 백업, 한 번에 복원 |
| Android USB 권한·전원 문제 | M | 3단계 시작 시 연결만 먼저 검증 |
| 블루투스 프로토콜이 공개되지 않음 | H | 7단계를 조사부터 시작하고 결과에 따라 범위를 줄이거나 보류 |
| 비공식 사용을 이유로 보증 수리 거절 가능성 | L | 펌웨어를 수정하지 않는다. 사용자가 감수하기로 함 |

---

## Implementation Phases

| # | Phase | Description | Status | Parallel | Depends | PRP Plan |
|---|-------|-------------|--------|----------|---------|----------|
| 1 | 카메라 연결 기반 (macOS) | X-T5 USB 연결, C1–C7 읽기·쓰기·검증, 백업·복원, 왕복 시간 측정 | complete (실기기 미확인) | - | - | [plans/phase-1-camera-link.plan.md](plans/phase-1-camera-link.plan.md) |
| 2 | 보관함·묶음·비교 | 디자인 시스템, Supabase 로그인·저장·동기화, 레시피 편집, 상황별 묶음, 비교 화면, 일괄 덮어쓰기 | complete (Supabase 연결·실기기 미확인) | - | 1 | [plans/phase-2-library.plan.md](plans/phase-2-library.plan.md) |
| 3 | Android | 같은 기능을 Android에서 USB로 | in-progress | - | 2 | [plans/phase-3-android.plan.md](plans/phase-3-android.plan.md) |
| 4 | 가져오기 | 카메라 슬롯 가져오기, JPEG EXIF 추출, OCR | pending | with 5 | 2 | - |
| 5 | RAW 미리보기 | RAF 업로드 → 카메라 내부 현상 → 좌우 비교 | pending | with 4 | 2 | - |
| 6 | 블루투스 조사 | 본인 카메라와 공식 앱의 BLE 통신 관찰, 슬롯 쓰기 가능 여부 판단 | pending | with 2–5 | 1 | - |
| 7 | 블루투스 연결 | 6단계 결과가 가능으로 나오면 구현 | pending | - | 3, 6 | - |

### Phase Details

**Phase 1: 카메라 연결 기반 (macOS)**
- **Goal**: X-T5와 PTP로 슬롯을 다룰 수 있음을 확인한다
- **Scope**: PTP 컨테이너 Dart 구현, macOS 플랫폼 채널, 7슬롯 읽기 화면(원시 값 표), 슬롯 1개 쓰기·검증, 7슬롯 백업 파일·복원, 왕복 시간 로그
- **Success signal**: 7슬롯을 읽고, 1개를 바꿔 쓰고, 백업으로 원래대로 되돌릴 수 있다. 7슬롯 쓰기 예상 시간이 측정되어 있다

**Phase 2: 보관함·묶음·비교**
- **Goal**: 핵심 가설을 macOS에서 검증한다
- **Scope**: Supabase 스키마(레시피, 묶음, 백업), 로그인, SQLite 캐시와 동기화, 레시피 편집 화면, 묶음 편집, 비교 화면, 일괄 덮어쓰기
- **Success signal**: 묶음 하나를 골라 비교를 보고 7슬롯을 10초 안에 덮어쓴다

**Phase 3: Android**
- **Goal**: 현장에서 휴대폰으로 같은 흐름을 쓴다
- **Scope**: Kotlin USB 플랫폼 채널, 권한 처리, 화면 크기 대응
- **Success signal**: 휴대폰과 X-T5를 케이블로 연결해 앱 실행부터 30초 안에 묶음을 교체한다

**Phase 4: 가져오기**
- **Goal**: 레시피를 손으로 입력하지 않고 보관함에 넣는다
- **Scope**: 카메라 슬롯 → 보관함, 후지 JPEG EXIF 파싱, 이미지 OCR 파싱(macOS Vision, Android ML Kit)
- **Success signal**: 세 경로 각각으로 레시피 1개가 값 손실 없이 들어온다 (EXIF에 없는 값은 빈칸으로 표시)

**Phase 5: RAW 미리보기**
- **Goal**: 레시피 값의 효과를 내 사진으로 본다
- **Scope**: RAF 업로드(`0x900C`/`0x900D`), 프로필 `0xD185` 수정, 변환 `0xD183`, JPEG 회수, 좌우 비교 화면
- **Success signal**: RAF 1장에 두 레시피를 적용한 결과를 나란히 본다

**Phase 6: 블루투스 조사**
- **Goal**: BLE로 슬롯을 쓸 수 있는지 판단한다
- **Scope**: 공개 자료 조사(petabyt/fudge 등), 본인 카메라와 공식 앱 사이 BLE 통신 관찰, 결과 문서화
- **Success signal**: "가능 / 불가능 / 부분 가능"과 그 근거가 문서로 남는다

**Phase 7: 블루투스 연결**
- **Goal**: 케이블 없이 묶음을 교체한다
- **Scope**: 6단계 결과에 따라 정한다
- **Success signal**: TBD - 6단계 결과에 따름

### Parallelism Notes

4와 5는 서로 다른 기능(가져오기 vs 현상)이고 레시피 모델만 공유하므로 2단계 이후 동시에 진행할 수 있다. 6은 조사 작업이라 1단계 뒤 언제든 다른 단계와 함께 진행할 수 있다. 3은 2의 화면과 저장 구조를 그대로 옮기므로 2 뒤에 둔다.

---

## Decisions Log

| Decision | Choice | Alternatives | Rationale |
|----------|--------|--------------|-----------|
| 스택 | Flutter + Supabase | 웹(Next.js), SwiftUI | macOS와 Android를 한 코드로. 사용자 선택 |
| 저장 | Supabase 원본 + 기기 캐시 | 기기 전용, Supabase 전용 | 사용자는 처음부터 클라우드를 원함. 현장 오프라인 때문에 캐시 필요 |
| 기기 사본 형식 | JSON 파일 | SQLite | 레코드가 수십 개 규모. 1단계의 원자적 JSON 저장을 그대로 씀 (2026-10-17) |
| 디자인 시스템 | 2단계에 포함, 카메라 다이얼풍 어두운 테마 | 나중에, 밝은 사진 앱풍 | 사용자 결정 (2026-10-17) |
| 실기기 시험 | 2단계는 가짜 전송으로 검증 | 실기기 확인 뒤 진행 | 사용자가 카메라 시험을 할 수 없음 (2026-10-17). 1단계 열린 질문은 유지 |
| 첫 플랫폼 | macOS → Android | Android 먼저 | macOS는 `ImageCaptureCore` 경로가 확인되어 있어 연결 검증이 빠르다 |
| Android 순서 | 2단계 직후 | 마지막 | 실제 사용 상황이 현장 이동 중이다 |
| 카메라 연결 | USB PTP 먼저, BLE는 조사 후 | BLE 먼저 | USB는 공개 자료가 있고, BLE는 없다 |
| 쓰기 방식 | 바뀐 값만 쓰기 + 다시 읽어 검증 | 전체 값 쓰기 | 10초 목표, 비교 화면과 같은 diff 사용 |
| 범위 | 커뮤니티·동영상 제외 | 포함 | 본인용 앱 |

---

## Research Summary

**Market Context**
- Fuji X Weekly 앱(2026년 8월): USB-C PTP 전송, X-T5 지원. 1개 전송 무료, 레시피 세트는 유료. ISO·노출 보정은 전송 안 됨. DR·클래리티는 카메라가 거부할 수 있음. 작성자가 보증 영향 가능성을 경고
- Community for Fuji 1.9.10: Flutter + Supabase. 묶음(loadout), 슬롯 백업, RAF 현상, BLE(베타). C4–C7은 Pro 전용 (`analysis.md`)
- FilmKit: MIT, 브라우저 WebUSB, 슬롯 1개씩 편집. X100VI만 확인

**Technical Context**
- 프로토콜: FilmKit `QUICK_REFERENCE.md`, `src/ptp/constants.ts`, `src/profile/enums.ts`. 근거 프로젝트는 rawji, fudge, libgphoto2
- 카메라 설정: `PC 연결 모드 → USB RAW 변환/백업 복원`. USB vendor ID `0x04CB`
- 코드베이스 없음 (신규 프로젝트)

---

*Generated: 2026-10-16*
*Status: DRAFT - needs validation*
