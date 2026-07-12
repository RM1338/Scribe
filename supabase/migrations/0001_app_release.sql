-- Holds the latest published build of the app, per platform, so the running
-- app can tell users when a newer version is available for download from the
-- website. One row per platform; update it whenever you publish a release.
create table if not exists public.app_release (
  platform text primary key check (platform in ('android', 'ios')),
  latest_version text not null,          -- user-facing version, e.g. '1.2.0'
  latest_build int not null default 0,   -- build number, the +N in pubspec version
  download_url text not null,            -- where the banner sends users
  release_notes text,                    -- optional, shown under the banner title
  min_supported_version text,            -- reserved for a future forced-update gate
  updated_at timestamptz not null default now()
);

-- The app reads this with the anon key, so allow public SELECT but no writes.
-- Update rows from the Supabase dashboard / a service-role key only.
alter table public.app_release enable row level security;

drop policy if exists "public read app_release" on public.app_release;
create policy "public read app_release"
  on public.app_release
  for select
  using (true);

-- Seed rows. Replace download_url with your real links and bump the version /
-- build each time you publish. Keeping latest_version/build equal to the
-- shipped app means no banner shows until you raise them.
insert into public.app_release (platform, latest_version, latest_build, download_url, release_notes)
values
  ('android', '0.1.0', 1, 'https://your-website.com/download', null),
  ('ios',     '0.1.0', 1, 'https://your-website.com/download', null)
on conflict (platform) do nothing;
