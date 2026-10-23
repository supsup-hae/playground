# Plan: 사진 색인·위치 기록 동기화 (사진 기록 6단계)

## Summary
지금 있는 동기화 버튼(레시피·세트)에 사진 색인과 세트 저장 기록을 더한다. 사진은 파일 없이 촬영 정보(파일 이름, 촬영 시각, 위치, 필름 시뮬레이션과 레시피 값)만 올린다. 다른 기기에서 색인한 사진은 썸네일 없이 목록·지도·찾기에 보이고, 같은 사진(파일 이름 + 촬영 시각)은 한 항목이다. 세트 저장 기록은 id 로 합친다.

## User Story
As X-T5 사용자, I want 휴대폰에서 색인한 사진과 저장 기록을 Mac 에서도 보기를, so that 어느 기기에서 찾든 같은 결과를 본다.

## Metadata
- **Complexity**: Medium
- **Source PRD**: `docs/photo-log.prd.md` 6단계
- **새 의존성**: 없음 (`supabase_flutter` 를 그대로 쓴다)

---

## 결정 필요 (승인 때 함께 정한다)

| # | 무엇 | 제안 | 다른 선택 | 이유 |
|---|---|---|---|---|
| D1 | 원격 사진 행의 키 | 화면에서 같은 사진을 가르는 키와 같은 것: 파일 이름(소문자) + 촬영 시각. 촬영 시각이 없는 사진은 올리지 않는다 | `PhotoInfo.key`(기종·시각·시간대·촬영 번호) | 화면의 중복 제거와 같은 기준이어야 다른 기기 사진과 이 기기 사진이 한 항목으로 합쳐진다 |
| D2 | 다른 기기 사진 표시 | 목록·지도·검색에 함께 보이고, 썸네일 자리에 "다른 기기"를 표시한다. 상세는 촬영 정보와 레시피만 보이고 "이 기기에 없는 사진"이라고 알린다. 같은 사진이 이 기기에도 있으면 이 기기 것을 쓴다 | 따로 "다른 기기" 필터 | PRD 성공 기준이 "다른 기기의 목록에 보인다(썸네일 없이)" 다 |
| D3 | 지우기 | 더하기만 한다. 출처를 빼거나 사진을 지워도 원격 행은 남는다 | 출처를 빼면 그 출처 사진의 원격 행도 지운다 | 기록은 오래 남는 것이 목적이다. 어느 기기 출처에서 온 행인지 따로 추적하지 않아도 된다 |
| D4 | 장소 이름 캐시 | 동기화하지 않는다. 기기마다 좌표 캐시로 주소 변환을 한다 | `places` 테이블로 공유 | 같은 좌표는 기기마다 한 번만 묻고, 테이블·정책이 하나 줄어든다 |
| D5 | 테이블 만들기 | `supabase/photo-log.sql` 새 파일. 사용자가 Supabase SQL 편집기에서 한 번 실행한다 | Supabase MCP 로 제가 적용(그때 따로 허락받음) | 기존 `setup.sql` 은 정책을 다시 만들면 실패하므로 새 테이블만 따로 둔다 |

---

## 동작

- **언제**: 지금의 동기화와 같은 때(앱을 열 때 로그인돼 있으면, 동기화 버튼, 로그인 직후). 보관함을 맞춘 다음 사진과 기록을 맞춘다. 사진 쪽이 실패해도 보관함 동기화 결과는 그대로 두고 로그에 남긴다
- **사진**: 원격 행을 모두 받는다(1,000행씩). 이 기기 사진 중 원격에 없거나 내용(위치 등)이 다른 것만 올린다. 받은 행은 `photos.json` 의 "다른 기기" 칸에 두어 오프라인에서도 보인다
- **기록**: 원격 기록을 모두 받아 없는 id 만 더하고, 원격에 없는 이 기기 기록만 올린다
- **로그**: `사진 동기화: 받음 N, 올림 M, 기록 받음 K, 올림 L`

### 테이블 (`supabase/photo-log.sql`)
```sql
photos(user_id uuid default auth.uid(), key text, body jsonb, updated_at timestamptz, primary key (user_id, key))
place_logs(user_id uuid default auth.uid(), id text (16진 32자), body jsonb, logged_at timestamptz, primary key (user_id, id))
```
- RLS: 본인 행만 select·insert·update(기존 `recipes` 와 같은 정책 모양). delete 권한은 주지 않는다(D3)
- `body`: 사진은 `{name, info}`(앱의 `PhotoInfo` JSON), 기록은 앱의 `PlaceLog` JSON

---

## Files to Change

| File | Action | 내용 |
|---|---|---|
| `supabase/photo-log.sql` | CREATE | 두 테이블, 주석, 색인, 권한, RLS |
| `lib/sync/remote_photos.dart` | CREATE | `RemotePhotos` 인터페이스(`fetchPhotos`·`upsertPhotos`·`fetchLogs`·`upsertLogs`), `SupabaseRemotePhotos` |
| `lib/sync/photo_sync.dart` | CREATE | 받기·합치기·올리기. 사진 키·내용 비교, 기록 id 합치기 |
| `lib/photo/photo_index_store.dart` | UPDATE | "다른 기기" 사진 칸(`remotePhotos`, `replaceRemote`), `photos` 가 이 기기 사진을 먼저 쓰며 합친다, `sameKey` 를 공개 |
| `lib/photo/place_log_store.dart` | UPDATE | `addAll`(없는 id 만) |
| `lib/sync/sync_service.dart` | UPDATE | 보관함 다음에 `PhotoSync` 를 부른다(있을 때) |
| `lib/ui/photo_thumbnail.dart`, `photo_detail_page.dart` | UPDATE | 다른 기기 사진 표시 |
| `lib/main.dart` | UPDATE | 연결 |
| 시험: `photo_sync_test`, `photo_index_store_test`, `place_log_store_test`, `sync_service_test`, 화면 시험 | CREATE/UPDATE | 가짜 원격 |
| `docs/photo-log.prd.md`, `docs/unverified.md`, `README.md` | UPDATE | 6단계 진행, 실행할 SQL, 미확인 항목 |

## NOT Building
- 사진 파일·썸네일 업로드 (PRD 범위 밖)
- 원격 행 지우기(D3), 장소 이름 공유(D4)
- 실시간 구독 — 동기화 버튼과 앱 시작 때만

## Testing Strategy

| Test | Expected |
|---|---|
| 처음 동기화: 이 기기 사진 올림, 원격 사진 받음 | 가짜 원격에 행, `remotePhotos` 에 받은 행 |
| 같은 키 사진이 두 기기에 있으면 화면에 한 항목, 이 기기 것 | `photos` |
| 내용이 같으면 다시 올리지 않고, 위치가 새로 생기면 올린다 | 업로드 수 |
| 촬영 시각이 없는 사진·읽지 못한 사진은 올리지 않는다 | |
| 형식이 틀린 원격 행은 건너뛴다 | 로그 |
| 기록: 없는 id 만 받고, 원격에 없는 것만 올린다 | |
| 사진 동기화 실패해도 보관함 동기화는 성공 | `sync()` 결과, 로그 |
| 저장 뒤 다시 읽어도 다른 기기 사진이 남는다 | |
| 화면: 다른 기기 사진 썸네일 자리에 "다른 기기", 상세에 "이 기기에 없는 사진" | |

## Validation Commands
```bash
cd Project/recipe-slot-manager
flutter analyze
dart format --set-exit-if-changed lib test tool
flutter test
flutter build macos --debug
flutter build apk --debug
```

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| 사진 수천 장을 매번 받는다 | M | L | 행이 작다(수백 바이트). 느리면 `updated_at` 이후만 받기로 바꾼다 |
| 사용자가 SQL 을 실행하지 않으면 테이블이 없다 | M | M | 사진 동기화만 실패하고 로그에 "photo-log.sql 을 실행하세요" 를 남긴다. 보관함 동기화는 그대로 |
| 실기기·실서버 미확인 | H | M | 가짜 원격 시험, `docs/unverified.md` |

---

## 구현 중 바뀐 점

- 올리는 기준: 원격에 없는 사진, 또는 원격에는 위치가 없는데 이 기기에 위치가 있는 사진. 내용 전체를 비교하지 않으며, 위치 없는 사본이 원격의 위치를 지우지 않는다
- 같은 사진이 이 기기에도 있으면 이 기기 것을 쓰되, 이 기기 사본에 위치가 없으면 다른 기기 사본의 위치를 빌린다(썸네일은 이 기기 파일로 읽는다)
- 테이블이 없을 때 로그는 Supabase 오류 문장을 그대로 남긴다(`사진 동기화 실패: …`). 실행할 SQL 은 README 에 적었다
- 다른 기기 사진은 출처 id 가 빈 문자열(`otherDeviceSourceId`)인 항목으로 `photos.json` 에 함께 저장한다
