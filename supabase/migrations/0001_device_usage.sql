-- Device-scoped free quota.
--
-- Transcriptions are metered against the *device*, not the account, so signing
-- out and creating a fresh account inherits the same used-up allowance. This is
-- what stops free-tier farming; an account-scoped counter does not.
--
-- Nothing here is enforceable from the Flutter client -- a client can always
-- lie about how much it has used. The counter therefore lives in Postgres and
-- is only reachable through a SECURITY DEFINER function that increments it
-- atomically. The table itself is unreachable: RLS is on and no policy grants
-- select/insert/update/delete to anon or authenticated.

create table if not exists public.device_usage (
  device_id            text primary key,
  transcriptions_used  integer     not null default 0 check (transcriptions_used >= 0),
  last_user_id         uuid        references auth.users (id) on delete set null,
  first_seen_at        timestamptz not null default now(),
  last_seen_at         timestamptz not null default now()
);

alter table public.device_usage enable row level security;

-- Deliberately no policies. With RLS enabled and no policy, direct access from
-- anon/authenticated is denied outright; only the definer functions below can
-- read or write this table. Do not add a policy here "for convenience" -- that
-- would hand the client the ability to reset its own counter.

revoke all on table public.device_usage from anon, authenticated;


-- Free transcriptions allowed per device, before payment is required.
-- Change this in one place.
create or replace function public.device_free_quota()
returns integer
language sql
immutable
as $$ select 10 $$;


-- Reports quota state without consuming any. Safe to call on app start.
create or replace function public.get_device_quota(p_device_id text)
returns table (used integer, quota integer, remaining integer)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_used  integer;
  v_quota integer := public.device_free_quota();
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;
  if p_device_id is null or length(trim(p_device_id)) = 0 then
    raise exception 'device_id is required' using errcode = '22023';
  end if;

  select d.transcriptions_used into v_used
    from public.device_usage d
   where d.device_id = p_device_id;

  v_used := coalesce(v_used, 0);

  return query select v_used, v_quota, greatest(v_quota - v_used, 0);
end;
$$;


-- Consumes one unit of quota if any remains. Returns whether it was allowed
-- along with the resulting counts, so the client never has to compute them.
--
-- The INSERT ... ON CONFLICT DO UPDATE takes a row lock, so two concurrent
-- transcriptions on the same device serialise here rather than both reading
-- `used = 9` and both being allowed through.
create or replace function public.consume_device_quota(p_device_id text)
returns table (allowed boolean, used integer, quota integer, remaining integer)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_used  integer;
  v_quota integer := public.device_free_quota();
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;
  if p_device_id is null or length(trim(p_device_id)) = 0 then
    raise exception 'device_id is required' using errcode = '22023';
  end if;

  insert into public.device_usage as d (device_id, last_user_id)
       values (p_device_id, auth.uid())
  on conflict (device_id) do update
          set last_user_id = auth.uid(),
              last_seen_at = now()
    returning d.transcriptions_used into v_used;

  if v_used >= v_quota then
    return query select false, v_used, v_quota, 0;
    return;
  end if;

  update public.device_usage
     set transcriptions_used = transcriptions_used + 1
   where device_id = p_device_id
   returning transcriptions_used into v_used;

  return query select true, v_used, v_quota, greatest(v_quota - v_used, 0);
end;
$$;


-- Only signed-in users may ask about or spend quota.
revoke all on function public.get_device_quota(text) from public, anon;
revoke all on function public.consume_device_quota(text) from public, anon;
grant execute on function public.get_device_quota(text) to authenticated;
grant execute on function public.consume_device_quota(text) to authenticated;
