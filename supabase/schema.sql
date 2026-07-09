-- Scribe auth schema
-- Run this once in your Supabase project's SQL Editor (Dashboard -> SQL Editor -> New query).
--
-- What this does:
--   1. Creates a `profiles` table with exactly one row per user (1:1 with auth.users).
--   2. Enables Row Level Security so a user can only ever read/update their OWN row.
--      This is the actual guarantee behind "only authorised users can access their own
--      account" -- it's enforced by Postgres on every query, not by app code.
--   3. Auto-creates a profile row the moment someone signs up (before OTP is even verified).

create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  email      text not null,
  full_name  text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Deliberately no insert/delete policy for the `authenticated` role: with RLS
-- enabled and no matching policy, Postgres denies those commands outright.
-- Rows are created only by the trigger below (SECURITY DEFINER, bypasses RLS),
-- so a client can never create/delete a profile row for a uid that isn't its own.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, new.raw_user_meta_data ->> 'full_name');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
