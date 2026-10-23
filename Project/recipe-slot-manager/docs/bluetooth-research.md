# 블루투스 조사 (6단계)

결론: **부분 가능.** X-T5 의 블루투스로 슬롯 값 하나를 바꾸는 명령은 공개 자료에 없다. 다만 카메라 전체 설정 백업 파일(`backup.dat`)을 블루투스로 읽고 되돌려 쓰는 길이 있고, 다른 앱이 이 길로 슬롯을 쓴다. 이 길을 쓰려면 X-T5 백업 파일 안의 슬롯 위치와 파일 전송 절차를 실기기 관찰로 알아내야 한다.

조사일: 2026-10-23. 방법: 공개 저장소의 코드와 문서, 설치된 Community for Fuji 1.9.10 의 문자열과 번역 파일(실행·디컴파일·통신 관찰은 하지 않음).

## 후지 카메라의 블루투스가 하는 일

| 기능 | 근거 |
|---|---|
| 페어링(구형·보안 방식) | furble `FujifilmSecure.cpp`, libfuji `lib/bluetooth.c` |
| 위치·시각 보내기 | furble 의 geotag 서비스, libfuji 의 time 특성 |
| 원격 셔터 | furble 의 shutter 서비스 |
| Wi-Fi SSID·비밀번호 받기 | libfuji 의 `CHR_UNKNOWN1_SSID`·`_PASSWORD` |
| 파일 읽기(백업 `backup.dat`, 장비 상태 JSON) | libfuji 의 `SVC_BACKUPS`(`af854c2e-…`). 파일 정보 예: 이름 `backup.dat`, 크기 `0x827c`(33,404 바이트). 읽기 절차는 libfuji 에 구현돼 있지 않다 |

설정 변경과 사진 전송은 Wi-Fi 의 PTP/IP(카메라 `192.168.0.1:55740`)로 한다(Fudge 개발 기록). Wi-Fi 로 슬롯 값을 쓸 수 있는지는 공개 자료에 없다. fujifilm-ptp-reference 는 Wi-Fi 와 블루투스를 다루지 않는다.

## 다른 앱이 블루투스로 슬롯을 쓰는 방식

- **FUJIFILM XApp**: 카메라 설정 백업·복원(전체 설정 한 벌)
- **Community for Fuji 1.9.10**: "블루투스로 레시피 설치(베타)". 번역 파일과 문자열로 본 동작:
  - 쓰기 전에 카메라 전체 설정을 휴대폰에 백업하고, 백업 파일의 슬롯 표를 고쳐 복원한다
  - 레시피 하나에 약 10초, 세트(키트)는 한 번에 보낸다
  - X-T50 만 검증됐고 X-T5 를 포함한 X-Trans V·IV 는 베타다
  - 기종별 슬롯 표를 다 알아내지 못한 기종은 읽기 전용으로 둔다
  - X-Pro3·X-T4 이전 기종과 구형 Camera Remote 전용 기종은 블루투스로 설정을 보낼 수 없다
  - 문자열에 백업 파일 형식 표식(`backup magic`, `verified backup code`)과 조각 단위 복원(`restore NOT accepted: chunk …`)이 있다

## 쓸 수 있는 길

| 길 | 가능성 | 필요한 것 | 위험 |
|---|---|---|---|
| A. 블루투스로 백업 읽기 → 슬롯 표 고치기 → 복원 | 있음(다른 앱이 한다) | 파일 서비스 읽기·쓰기 절차, X-T5 `backup.dat` 의 슬롯 위치와 검증 코드 | 잘못 고치면 카메라 전체 설정이 바뀐다. 복원 전 백업 필수 |
| B. Wi-Fi PTP/IP 로 지금 USB 와 같은 속성 쓰기 | 모름 | PTP/IP 연결(공개), 무선 모드에서 슬롯 속성이 열리는지 | 실기기로만 확인된다 |
| C. 지금처럼 USB | 됨 | — | — |

## 실기기 관찰 절차 (A 를 위해)

갤럭시 S26 울트라와 X-T5, FUJIFILM XApp 으로 한다. 관찰 기록에는 기기 주소가 들어 있으므로 저장소에 올리지 않는다.

1. 휴대폰 개발자 옵션에서 "블루투스 HCI 스누프 로그"를 켜고 블루투스를 껐다 켠다
2. XApp 에서 카메라 설정 **백업**을 한 번 한다
3. 카메라에서 C1 의 값 하나(예: 하이라이트 0 → +1)만 바꾸고, 다시 **백업**한다
4. XApp 에서 첫 백업을 **복원**한다
5. 휴대폰에서 버그 리포트를 만들어(`adb bugreport` 또는 개발자 옵션) `btsnoop_hci.log` 를 꺼낸다
6. XApp 이 백업 파일을 밖으로 내보내는지는 확인하지 못했다. 두 `backup.dat` 는 관찰 기록 안의 파일 전송 내용을 이어 붙여 다시 만든다. 다시 만들 수 없으면 7a 구현 뒤 이 앱의 "블루투스로 백업 읽기"로 두 벌을 받는다
7. 두 백업 파일의 차이로 C1 하이라이트 위치를, 관찰 기록으로 파일 읽기·복원 절차를 찾는다

## 출처

- [gkoh/furble](https://github.com/gkoh/furble) — 후지 블루투스 원격 셔터, 서비스·특성 UUID
- [petabyt/libfuji](https://github.com/petabyt/libfuji) — 후지 USB·Wi-Fi·블루투스 라이브러리, 파일 서비스 메모
- [Fudge 1년 기록](https://danielc.dev/blog/fudge1/) — Wi-Fi PTP/IP
- [zgrimz/fujifilm-ptp-reference](https://github.com/zgrimz/fujifilm-ptp-reference) — USB 슬롯 쓰기 참고서(무선은 범위 밖)
- `docs/analysis.md` — Community for Fuji 구조 분석
