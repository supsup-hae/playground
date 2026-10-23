-- Recipe Slot Manager 사진 기록 테이블, 권한, RLS 정책. setup.sql 다음에 한 번 실행한다.
-- 행은 더하고 고치기만 한다(delete 권한 없음).

create table if not exists public.photos (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  key text not null check (char_length(key) between 1 and 300),
  body jsonb not null,
  updated_at timestamptz not null,
  primary key (user_id, key)
);

create table if not exists public.place_logs (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null check (id ~ '^[0-9a-f]{32}$'),
  body jsonb not null,
  logged_at timestamptz not null,
  primary key (user_id, id)
);

comment on table public.photos is '사용자별 사진 색인. 사진 파일은 없고 촬영 정보만 있다.';
comment on column public.photos.key is '같은 사진 키: 파일 이름(소문자)|촬영 시각.';
comment on column public.photos.body is '앱의 RemotePhoto JSON (key, name, info).';
comment on column public.photos.updated_at is '마지막으로 올린 시각.';
comment on table public.place_logs is '사용자별 세트 저장 기록: 세트를 카메라에 저장한 시각·위치·세트.';
comment on column public.place_logs.body is '앱의 PlaceLog JSON.';
comment on column public.place_logs.logged_at is '세트를 저장한 시각.';

revoke all on public.photos, public.place_logs from anon, authenticated;
grant select, insert, update on public.photos to authenticated;
grant select, insert, update on public.place_logs to authenticated;

alter table public.photos enable row level security;
alter table public.place_logs enable row level security;

create policy "photos: select own" on public.photos
  for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "photos: insert own" on public.photos
  for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "photos: update own" on public.photos
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "place_logs: select own" on public.place_logs
  for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "place_logs: insert own" on public.place_logs
  for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "place_logs: update own" on public.place_logs
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
