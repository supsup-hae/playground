-- Recipe Slot Manager 보관함 테이블, 권한, RLS 정책.

create table if not exists public.recipes (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null check (id ~ '^[0-9a-f]{32}$'),
  body jsonb not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  primary key (user_id, id)
);

create table if not exists public.loadouts (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text not null check (id ~ '^[0-9a-f]{32}$'),
  body jsonb not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  primary key (user_id, id)
);

comment on table public.recipes is '사용자별 필름 레시피. 행 하나가 앱의 Recipe 하나다.';
comment on column public.recipes.body is '앱의 Recipe JSON (id, name, tags, values, updatedAt, deletedAt).';
comment on column public.recipes.updated_at is '앱에서 마지막으로 저장한 시각. 동기화 병합 기준.';
comment on column public.recipes.deleted_at is '삭제한 시각. 행은 지우지 않는다.';
comment on table public.loadouts is '사용자별 상황 묶음. 행 하나가 앱의 Loadout 하나다.';
comment on column public.loadouts.body is '앱의 Loadout JSON (id, name, slots 7칸, updatedAt, deletedAt).';
comment on column public.loadouts.updated_at is '앱에서 마지막으로 저장한 시각. 동기화 병합 기준.';
comment on column public.loadouts.deleted_at is '삭제한 시각. 행은 지우지 않는다.';

create index if not exists recipes_user_updated_idx on public.recipes (user_id, updated_at);
create index if not exists loadouts_user_updated_idx on public.loadouts (user_id, updated_at);

grant select, insert, update on public.recipes to authenticated;
grant select, insert, update on public.loadouts to authenticated;

alter table public.recipes enable row level security;
alter table public.loadouts enable row level security;

create policy "recipes: select own" on public.recipes
  for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "recipes: insert own" on public.recipes
  for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "recipes: update own" on public.recipes
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "loadouts: select own" on public.loadouts
  for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "loadouts: insert own" on public.loadouts
  for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "loadouts: update own" on public.loadouts
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
