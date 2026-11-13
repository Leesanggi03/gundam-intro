-- =====================================================================
-- 02. 방명록 도배 방지 + 관리자 삭제
-- Supabase 대시보드 → SQL Editor 에 전체를 붙여넣고 Run 하세요.
-- 여러 번 실행해도 안전합니다.
-- =====================================================================

-- ---------- 1. 도배 방지용 컬럼/인덱스 ----------
-- ip_hash: 글쓴이 IP를 그대로 저장하지 않고 해시값만 저장 (방문자에게는 공개되지 않음)
alter table public.guestbook add column if not exists ip_hash text;
create index if not exists guestbook_ip_time_idx on public.guestbook (ip_hash, created_at desc);
create index if not exists guestbook_time_idx    on public.guestbook (created_at desc);

-- ---------- 2. 글 등록 전 검사 (DB에서 강제되므로 사이트를 우회해도 적용됨) ----------
create or replace function public.guestbook_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  hdrs   json;
  ip     text;
  recent int;
begin
  -- 요청 헤더에서 접속 IP 확인
  hdrs := nullif(current_setting('request.headers', true), '')::json;
  ip   := nullif(btrim(coalesce(hdrs->>'cf-connecting-ip',
                                split_part(hdrs->>'x-forwarded-for', ',', 1))), '');

  -- 서버가 정하는 값 (사용자가 보낸 값은 무시)
  new.name       := btrim(new.name);
  new.message    := btrim(new.message);
  new.created_at := now();
  new.ip_hash    := case when ip is null then null else md5('gundam-guestbook:' || ip) end;

  -- 규칙 1: 링크(URL) 금지 → 광고 스팸 차단
  if new.message ~* '(https?://|www\.)' or new.name ~* '(https?://|www\.)' then
    raise exception using errcode = 'P0001', message = 'LINK_NOT_ALLOWED';
  end if;

  -- 규칙 2: 10분 안에 같은 내용 재등록 금지
  if exists (select 1 from public.guestbook
             where message = new.message
               and created_at > now() - interval '10 minutes') then
    raise exception using errcode = 'P0001', message = 'DUPLICATE';
  end if;

  if new.ip_hash is not null then
    -- 규칙 3: 같은 IP는 30초에 1개
    if exists (select 1 from public.guestbook
               where ip_hash = new.ip_hash
                 and created_at > now() - interval '30 seconds') then
      raise exception using errcode = 'P0001', message = 'TOO_FAST';
    end if;

    -- 규칙 4: 같은 IP는 1시간에 10개까지
    select count(*) into recent from public.guestbook
     where ip_hash = new.ip_hash
       and created_at > now() - interval '1 hour';
    if recent >= 10 then
      raise exception using errcode = 'P0001', message = 'HOURLY_LIMIT';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists guestbook_before_insert on public.guestbook;
create trigger guestbook_before_insert
  before insert on public.guestbook
  for each row execute function public.guestbook_before_insert();

revoke all on function public.guestbook_before_insert() from public, anon, authenticated;

-- ---------- 3. 관리자 목록 ----------
create table if not exists public.admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;

-- 현재 로그인한 사람이 관리자인지 확인하는 함수
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.admins where user_id = (select auth.uid()));
$$;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- ---------- 4. 방명록 권한 다시 정리 ----------
-- 방문자: 공개 컬럼만 읽기, 이름/기체/메시지만 쓰기 (ip_hash·created_at 은 못 건드림)
-- 관리자: 위 권한 + 삭제
revoke all on public.guestbook from anon, authenticated;
grant select (id, name, favorite_ms, message, created_at) on public.guestbook to anon, authenticated;
grant insert (name, favorite_ms, message)                 on public.guestbook to anon, authenticated;
grant delete                                              on public.guestbook to authenticated;

drop policy if exists "guestbook admin delete" on public.guestbook;
create policy "guestbook admin delete"
  on public.guestbook for delete
  to authenticated
  using ((select public.is_admin()));

-- =====================================================================
-- 5. 관리자 등록 (계정을 만든 뒤 따로 실행)
--   ① Authentication → Users → Add user → Create new user
--      이메일/비밀번호 입력, "Auto Confirm User" 체크
--   ② 아래 줄의 이메일을 바꾼 뒤, 이 한 줄만 선택해서 실행
--
-- insert into public.admins (user_id)
--   select id from auth.users where email = 'admin@example.com'
--   on conflict do nothing;
-- =====================================================================
