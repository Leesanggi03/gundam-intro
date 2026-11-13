-- 건담 입문 가이드: 방명록 테이블
-- Supabase 대시보드 → SQL Editor 에 붙여넣고 Run 하세요.

create table if not exists public.guestbook (
  id          bigint generated always as identity primary key,
  name        text not null check (char_length(btrim(name)) between 1 and 20),
  favorite_ms text check (favorite_ms is null or char_length(favorite_ms) <= 30),
  message     text not null check (char_length(btrim(message)) between 1 and 300),
  created_at  timestamptz not null default now()
);

-- 행 단위 보안(RLS): 누구나 읽기/쓰기만 가능, 수정·삭제는 불가
alter table public.guestbook enable row level security;

drop policy if exists "guestbook read"  on public.guestbook;
drop policy if exists "guestbook write" on public.guestbook;

create policy "guestbook read"
  on public.guestbook for select
  to anon, authenticated
  using (true);

create policy "guestbook write"
  on public.guestbook for insert
  to anon, authenticated
  with check (true);

-- 클라이언트는 select / insert 만 사용
-- (Supabase는 기본적으로 모든 권한을 주므로, 수정·삭제 권한은 명시적으로 회수)
revoke all on public.guestbook from anon, authenticated;
grant select, insert on public.guestbook to anon, authenticated;
