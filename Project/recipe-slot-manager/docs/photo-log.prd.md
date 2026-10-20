# 사진 기록: 어디서 어떤 시뮬레이션으로 찍었나

## Problem Statement

X-T5 사진의 EXIF 에는 필름 시뮬레이션과 (XApp 위치 동기화를 켰다면) 촬영 위치가 들어 있다. 하지만 갤러리 앱은 위치만 보여 주고 후지 MakerNote 의 필름 시뮬레이션은 보여 주지 않는다. 그래서 "1년 전 일본에서 Eterna 로 찍은 골목 사진"을 찾으려면 사진을 한 장씩 열어 봐야 한다.

## Evidence

- 사용자 본인의 요구: 어떤 사진을 어디서 어떤 시뮬레이션으로 찍었는지 추적하고 싶다. 지금은 따로 기록하지 않는다
- XApp 으로 받은 표본 2장(2026-10-11, 3840×2560): MakerNote 73개 태그가 남아 있고 필름 시뮬레이션 Eterna(FilmMode `0x700`)와 레시피 값이 4단계 해석기로 읽힌다
- 같은 표본의 GPS IFD(`0x8825`)는 항목만 있고 값이 모두 0 이다. 위치 동기화가 꺼진 상태로 찍힌 것으로 보인다. 위치가 들어간 표본은 아직 없다
- 표본의 `DateTime`(15:36:13)과 `DateTimeOriginal`(15:26:10)이 다르다. 촬영 시각은 `DateTimeOriginal` 과 `OffsetTimeOriginal`(+09:00)로 정한다

## Proposed Solution

지정한 사진 폴더(휴대폰의 XApp 사진 폴더, Mac 의 폴더, 둘 다 하위 폴더 포함)를 읽어 사진마다 촬영 시각, 위치, 필름 시뮬레이션, 레시피 값을 색인한다. 위치는 기기의 주소 변환(macOS `CLGeocoder`, Android `Geocoder`)으로 나라·광역·도시·동네·길 이름으로 바꾼다. 기간·나라·도시·시뮬레이션으로 거른 목록과 지도로 사진을 찾는다. 카메라에 묶음을 쓸 때 휴대폰 위치를 함께 기록해 "어디서 어떤 레시피로 바꿨는지"도 남긴다. 색인과 기록은 Supabase 로 동기화하고, 사진 파일은 올리지 않는다.

## Key Hypothesis

We believe 사진 폴더 색인과 시뮬레이션·지역·기간 필터, 지도 will 사진을 한 장씩 열어 보는 일을 대체할 것이다 for X-T5 로 여행·거리 사진을 찍는 사용자(본인).
We'll know we're right when "1년 전 일본에서 어떤 골목에서 어떤 시뮬레이션으로 찍은 사진"을 앱을 연 뒤 30초 안에 찾을 때.

## What We're NOT Building

- 사진 파일 업로드·백업 - 동기화는 색인 정보만 한다. 미리보기는 그 기기에 있는 파일로만 보인다
- 위치 없는 사진의 위치 추정 - "위치 없음"으로 따로 모은다 (사용자 결정)
- 사진 편집, 앨범 정리, 파일 이동·삭제 - 읽기만 한다
- 오프라인 지도 - 지도 타일은 인터넷 연결이 있을 때만 보인다
- 후지 외 카메라 사진의 시뮬레이션 - 위치와 시각만 색인한다

## Success Metrics

| Metric | Target | How Measured |
|--------|--------|--------------|
| 조건 하나로 사진 찾기 | 앱을 연 뒤 30초 이내 | 직접 측정: "1년 전 일본, Eterna" 로 거른 뒤 지도에서 길 이름이 보이는 사진 상세까지 |
| 새 사진 색인 | 100장 10초 이내 | 앱 로그 (스캔 시작 → 색인 저장 끝) |
| 다시 색인할 때 다시 읽는 사진 | 바뀐 사진만 | 시험: 같은 폴더를 두 번 색인하면 두 번째는 파일을 읽지 않는다 |
| 기기 간 같은 사진 중복 | 0건 | 같은 사진이 휴대폰과 Mac 에 있을 때 동기화 뒤 항목 수 |

## Open Questions

- [ ] XApp 위치 동기화를 켜고 찍은 사진에 GPS 가 실제로 들어오는가, XApp 으로 받을 때 지워지지 않는가 - 사용자가 지금 시험할 수 없다. 가짜 EXIF 로 시험하고 `docs/unverified.md` 에 남긴다
- [x] Android 에서 XApp 이 사진을 저장하는 폴더 경로 - 시스템 폴더 선택 창에서 사용자가 고르게 해 경로에 기대지 않는다 (2단계)
- [x] 휴대폰과 Mac 에 있는 같은 사진을 무엇으로 판별하나 - 기종·촬영 시각·시간대·MakerNote 촬영 번호(`PhotoInfo.key`)로 정했다 (1단계). 촬영 번호가 맞는지는 `docs/unverified.md`
- [ ] macOS·Android 주소 변환의 호출 제한과 한국어로 받은 일본 주소의 형태 - 3단계에서 좌표 캐시로 호출 수를 줄인다
- [x] Mac 에서 묶음을 쓸 때도 위치를 기록할지 - 기록은 남기고 위치 칸만 비운다 (5단계 계획 D2)

---

## Users & Context

**Primary User**
- **Who**: X-T5 로 여행지와 거리를 찍고 XApp 으로 휴대폰에 사진을 옮기는 사용자(본인)
- **Current behavior**: 사진별 시뮬레이션과 장소를 따로 기록하지 않는다
- **Trigger**: 예전에 어디서 어떤 시뮬레이션으로 찍었는지 다시 보고 싶을 때, 같은 장소에 다시 갈 때
- **Success state**: 기간·나라·시뮬레이션을 고르면 지도에 사진이 찍히고, 사진을 누르면 길 이름과 레시피 값이 보인다

**Job to Be Done**
When 예전 여행 사진의 장소와 설정을 떠올리고 싶으면, I want to 시뮬레이션·지역·기간으로 사진을 거르고, so I can 그 골목과 그때 쓴 레시피를 바로 찾을 수 있다.

**Non-Users**
다른 사용자, 사진을 공유·백업하려는 사람.

---

## Solution Detail

### Core Capabilities (MoSCoW)

| Priority | Capability | Rationale |
|----------|------------|-----------|
| Must | 폴더 색인: 촬영 시각, GPS, 필름 시뮬레이션, 레시피 값 | 모든 보기의 재료 |
| Must | 바뀐 사진만 다시 읽는 색인 | 사진이 수천 장이 되어도 다시 색인이 짧아야 한다 |
| Must | 좌표 → 나라·광역·도시·동네·길 이름 | "일본", "골목"으로 찾는다 |
| Must | 기간·나라·도시·시뮬레이션 필터 목록, 위치 없음 묶음 | 30초 목표의 주 경로 |
| Must | 지도 (사진 위치 점, 필터 적용) | 길 단위 위치는 지도로 확인한다 |
| Must | 묶음을 쓸 때 휴대폰 위치 기록 (Android) | 사용자 결정 |
| Must | Supabase 동기화 (색인, 위치 기록) | 사용자 결정 |
| Should | 사진 상세에서 "이 설정을 레시피로 가져오기" | 4단계 EXIF 가져오기를 그대로 쓴다 |
| Could | 지도에서 위치 기록과 사진을 겹쳐 보기 | 레시피를 바꾼 곳과 찍은 곳 비교 |
| Won't | 사진 업로드, 위치 추정, 오프라인 지도 | 범위 밖 |

### MVP Scope

1–4단계. Mac 폴더와 휴대폰 XApp 사진 폴더를 색인하고, 필터 목록과 지도로 "1년 전 일본, Eterna" 사진을 찾는다.

### User Flow

1. "사진" 탭을 연다 (처음이면 폴더를 고른다)
2. 앱이 새 사진만 읽어 색인한다
3. 기간(2025년), 나라(일본), 시뮬레이션(Eterna)을 고른다
4. 지도에서 점을 눌러 사진, 길 이름, 레시피 값을 본다

---

## Technical Approach

**Feasibility**: HIGH (색인·필터·지도), MEDIUM (실제 GPS 유무)

**Architecture Notes**
- EXIF: `lib/import/jpeg_exif.dart` 의 `readIfd` 로 GPS IFD 를 읽는다. 지금 `_typeSizes` 에 RATIONAL(5)·SRATIONAL(10, 8바이트)이 없어 좌표 값 위치를 잘못 계산하므로 추가한다. 필름 시뮬레이션은 `fuji_makernote.dart` 의 `decodeFujiRecipe` 를 쓴다. 파일 앞 256 KiB 만 읽는다 (APP1 은 64 KiB 안)
- 폴더 읽기: macOS 는 `file_selector` 의 폴더 고르기와 재귀 탐색. Android 는 시스템 폴더 선택 창으로 폴더를 고르고 그 경로의 사진을 MediaStore 로 찾는다. 원본 EXIF 위치를 받으려고 `ACCESS_MEDIA_LOCATION` 과 `MediaStore.setRequireOriginal` 을 쓴다. 2단계 계획에서 `photo_manager` 대신 자체 채널(`PhotoChannel.kt`)로 정했다
- 주소 변환: OCR 채널과 같은 방식의 플랫폼 채널 (`CLGeocoder`, `android.location.Geocoder`). 두 쪽 결과가 같은 항목(나라, 광역, 도시, 동네, 길)을 준다. 좌표를 소수 넷째 자리(약 10 m)로 반올림해 캐시한다
- 지도: `flutter_map` + OpenStreetMap 타일. macOS·Android 모두 되고 API 키가 필요 없다. OSM 타일 이용 정책에 따라 User-Agent 를 넣는다
- 색인 저장: 기기 JSON(`writeJsonAtomically`, `SerialQueue`)과 Supabase 테이블. 위치는 개인정보이므로 RLS 로 본인 행만 읽고 쓴다
- 위치 기록: 묶음 쓰기가 끝날 때 휴대폰 위치, 묶음, 시각을 남긴다

**Technical Risks**

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| 실제 사진에 GPS 가 없다 (위치 동기화 꺼짐, XApp 이 지움) | H | 위치 없음 묶음과 시뮬레이션·기간 필터는 GPS 없이도 동작한다. 실기기 확인은 `docs/unverified.md` |
| Android 가 위치를 지운 사본을 준다 | M | `ACCESS_MEDIA_LOCATION` 과 원본 요청. 가짜 채널 시험과 실기기 확인 항목 |
| 주소 변환 호출 제한 | M | 좌표 캐시, 한 번에 보내는 수 제한, 결과를 Supabase 로 공유해 다른 기기에서 다시 묻지 않는다 |
| 사진이 수천 장일 때 지도·목록이 느려진다 | M | 지도 점 묶기(클러스터), 목록은 필요할 때 만든다 |
| 기기 간 같은 사진 판별 실패 | M | 1단계에서 판별 키를 표본으로 정한다 |

---

## Implementation Phases

| # | Phase | Description | Status | Parallel | Depends | PRP Plan |
|---|-------|-------------|--------|----------|---------|----------|
| 1 | 촬영 정보 읽기 | GPS IFD(RATIONAL), 촬영 시각·시간대, 필름 시뮬레이션 → 사진 정보 | complete (위치 든 실제 사진 미확인) | - | - | [plans/photo-log-1-photo-info.plan.md](plans/photo-log-1-photo-info.plan.md) |
| 2 | 사진 색인 | Mac·Android 폴더 고르기(하위 폴더 포함), 자동 색인, 권한, 바뀐 사진만 읽기, 기기 저장 | complete (실기기 미확인) | with 3 | 1 | [plans/photo-log-2-photo-index.plan.md](plans/photo-log-2-photo-index.plan.md) |
| 3 | 장소 이름 | 주소 변환 채널(macOS·Android), 좌표 캐시 | complete (실기기 미확인) | - | 1 | [plans/photo-log-3-4-places-browse.plan.md](plans/photo-log-3-4-places-browse.plan.md) |
| 4 | 찾기 화면 | 사진 탭: 목록·지도 전환, 기간·지역·시뮬레이션 필터와 검색, 위치 없음 묶음, 사진 상세 | complete (실기기 미확인) | - | 2, 3 | [plans/photo-log-3-4-places-browse.plan.md](plans/photo-log-3-4-places-browse.plan.md) |
| 5 | 위치 기록 | 묶음 쓰기 때 휴대폰 위치 기록, 기록 목록, 지도 겹쳐 보기 | complete (실기기 미확인) | - | 3, 4 | [plans/photo-log-5-place-log.plan.md](plans/photo-log-5-place-log.plan.md) |
| 6 | 동기화 | Supabase 테이블·RLS, 색인·기록 동기화, 같은 사진 합치기 | pending | - | 2, 5 | - |

### Phase Details

**Phase 1: 촬영 정보 읽기**
- **Goal**: JPEG 하나에서 찾기에 필요한 정보를 모두 꺼낸다
- **Scope**: `readIfd` 의 RATIONAL 지원, GPS 위도·경도(남·서 부호), 값이 모두 0 인 GPS 를 "위치 없음"으로, 촬영 시각과 시간대, 필름 시뮬레이션, 기기 간 판별 키
- **Success signal**: 표본 2장은 Eterna·위치 없음·2026-10-11 15:26 +09:00 으로, 가짜 EXIF 는 넣은 좌표대로 읽힌다

**Phase 2: 사진 색인**
- **Goal**: 고른 폴더의 사진 목록을 기기에 저장한다
- **Scope**: macOS 폴더 고르기·재귀 탐색, Android 폴더 고르기·권한, 앱을 열 때·돌아올 때 자동 색인, 경로·크기·수정 시각으로 바뀐 사진 판단, 진행 표시
- **Success signal**: 같은 폴더를 두 번 색인하면 두 번째는 파일을 읽지 않고, 새 사진 100장은 10초 안에 들어간다

**Phase 3: 장소 이름**
- **Goal**: 좌표를 나라·광역·도시·동네·길 이름으로 바꾼다
- **Scope**: Swift·Kotlin 채널, Dart 쪽 캐시, 실패와 오프라인 처리
- **Success signal**: 같은 반올림 좌표는 한 번만 묻고, 네트워크가 없으면 좌표만 저장했다가 다음에 다시 묻는다

**Phase 4: 찾기 화면**
- **Goal**: 30초 안에 사진을 찾는다
- **Scope**: 셸 목적지에 "사진"을 더한다(휴대폰 아래 탭은 디자인 화면을 빼고 다섯 개), 기간·나라·도시·시뮬레이션 필터, 위치 없음 묶음, 지도와 점 묶기, 사진 상세(썸네일, 길 이름, 레시피 값)
- **Success signal**: "2025년·일본·Eterna" 로 걸러 지도에서 사진 상세까지 간다. 휴대폰 크기에서 넘침이 없다

**Phase 5: 위치 기록**
- **Goal**: 어디서 어떤 레시피로 바꿨는지 남긴다
- **Scope**: Android 위치 권한, 묶음 쓰기 성공 뒤 위치·묶음·시각 저장, 기록 목록, 지도 겹쳐 보기
- **Success signal**: 묶음을 쓰면 기록 하나가 생기고, 위치 권한이 없어도 쓰기는 그대로 끝난다

**Phase 6: 동기화**
- **Goal**: 휴대폰과 Mac 이 같은 색인과 기록을 본다
- **Scope**: `photos`·`place_logs` 테이블, 본인 행만 허용하는 RLS, 기존 동기화 흐름에 추가, 같은 사진 합치기
- **Success signal**: 한 기기에서 색인한 사진이 다른 기기의 목록에 보이고(썸네일 없이), 같은 사진은 한 항목이다

### Parallelism Notes

2와 3은 1의 사진 정보만 공유하고 파일이 겹치지 않아 함께 진행할 수 있다. 5는 지도 겹쳐 보기 때문에 4 뒤에 둔다. 6은 저장할 모양이 정해진 2와 5 뒤에 둔다.

---

## Decisions Log

| Decision | Choice | Alternatives | Rationale |
|----------|--------|--------------|-----------|
| 사진 위치 | 휴대폰 XApp 사진 폴더 + Mac 폴더 | 한쪽만 | 사용자 결정 (2026-10-19) |
| 보기 | 지도 + 지역별 목록 | 하나만 | 사용자 결정 (2026-10-19) |
| 지역 단위 | 주소 이름 (나라 → 길) | 가까운 점 묶기만 | 사용자 결정. 성공 기준이 "골목"이라 길 이름까지 받는다 |
| 색인 방식 | 바뀐 사진만 다시 읽기 | 매번 전체 | 사용자 결정 (2026-10-19) |
| 동기화 | Supabase, 사진 파일은 제외 | 기기별 저장 | 사용자 결정 (2026-10-19) |
| 폴더 지정·자동 색인 | 두 플랫폼 모두 폴더(하위 포함) 지정, 앱을 열 때·돌아올 때 자동 색인 | Android 앨범만, 버튼으로만 | 사용자 결정 (2026-10-20). Android 는 SAF 로 고르고 MediaStore 로 읽는다(SAF 로 읽으면 위치가 지워질 수 있음) |
| 위치 없는 사진 | "위치 없음"으로 모으기 | 시각으로 위치 추정 | 사용자 결정 (2026-10-19) |
| 주소 변환 | 플랫폼 채널 (`CLGeocoder`, `Geocoder`) | 외부 API, 패키지 | API 키가 없고, OCR 채널과 같은 구조로 가짜 채널 시험이 된다 |
| 지도 | `flutter_map` + OSM | Google Maps | macOS 지원, API 키 없음 |
| 위치 기록 범위 | 세트 저장(C1–C7)만, Mac 은 위치 없이 기록, 권한은 저장 직전에 묻는다 | 슬롯 하나 저장도 기록, Mac 미기록 | 5단계 계획 D1–D3 (2026-10-20) |
| 기록 보기 | 사진 탭의 세 번째 보기 "기록", 지도에 "세트 저장 위치" 칩 | 세트 탭의 "저장 기록" 화면 | 사용자 결정 (2026-10-20) |

---

## Research Summary

**Market Context**
- 갤러리 앱(Google 포토, 삼성 갤러리, Apple 사진)은 지도 보기가 있지만 후지 MakerNote 의 필름 시뮬레이션은 보여 주지 않는다
- Lightroom 은 기본 상태로 필름 시뮬레이션을 보여 주지 않는다

**Technical Context**
- 재사용: `readIfd`·`ifdValues`·`readMakerNote`(`lib/import/jpeg_exif.dart`), `readFujiTags`·`decodeFujiRecipe`(`lib/import/fuji_makernote.dart`), `pickJpegHead` 의 256 KiB 읽기(`lib/import/file_pick.dart`), OCR 플랫폼 채널 구조, `writeJsonAtomically`·`SerialQueue`, 2단계 동기화
- X-T5 는 GPS 가 없고, XApp 이 블루투스로 휴대폰 위치를 보내 줄 때만 GPS IFD 에 값이 들어간다
- 들인 의존성: `flutter_map`·`latlong2`(4단계). Android 사진 접근은 자체 채널로 했다

---

*Generated: 2026-10-19*
*Status: DRAFT - needs validation*
