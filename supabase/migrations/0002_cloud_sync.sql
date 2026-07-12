-- Cloud sync for Scribe: text-only mirrors of each user's meetings, folders
-- and scheduled meetings, so the web app and future devices can see them.
--
-- Each row stores the record's full JSON (as the Flutter models serialize it)
-- in a jsonb `data` column. The schema therefore never needs migrating when
-- the model gains a field. Audio is deliberately NOT stored here: recordings
-- stay on the device that made them (free-tier friendly), so `data` for a
-- meeting is uploaded with `audioFilePath` stripped.

create table if not exists public.meetings (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table if not exists public.folders (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table if not exists public.scheduled_meetings (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

-- Owners only: every operation is scoped to the signed-in user.
alter table public.meetings enable row level security;
alter table public.folders enable row level security;
alter table public.scheduled_meetings enable row level security;

drop policy if exists "own meetings" on public.meetings;
create policy "own meetings" on public.meetings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own folders" on public.folders;
create policy "own folders" on public.folders
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own scheduled_meetings" on public.scheduled_meetings;
create policy "own scheduled_meetings" on public.scheduled_meetings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
