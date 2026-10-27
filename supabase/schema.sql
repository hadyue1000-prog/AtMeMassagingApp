-- =============================================================================
--  AtMe (@Me) — Supabase Schema
--  Tables: profiles, conversations, messages
--  + RLS policies + Realtime + Storage buckets (voice-notes, avatars)
--
--  How to run:
--    Supabase Dashboard → SQL Editor → New query → paste this file → Run.
--    The script is idempotent (safe to run more than once).
--
--  Required Auth settings (Dashboard):
--    1) Authentication → Providers → Email: enabled.
--    2) Authentication → Email Templates → "Magic Link":
--         put the 6-digit code in the template, e.g.
--           <h2>رمز الدخول إلى @Me</h2>
--           <p>رمز التحقق الخاص بك هو: <strong>{{ .Token }}</strong></p>
--       (without {{ .Token }} Supabase sends a link instead of a code).
--    3) Authentication → Providers → Email → "Email OTP Length" = 6.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0) Extensions
-- -----------------------------------------------------------------------------
create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm  with schema extensions;


-- =============================================================================
-- 1) PROFILES
-- =============================================================================
create table if not exists public.profiles (
  id                     uuid        primary key
                                     references auth.users (id) on delete cascade,
  email                  text        not null unique,
  username               text        not null unique,
  display_name           text        not null,
  avatar_url             text,
  is_online              boolean     not null default false,
  is_profile_discoverable boolean    not null default true,
  last_seen              timestamptz not null default now(),
  created_at             timestamptz not null default now(),

  -- lowercase english letters, digits and underscore only (3..20 chars)
  constraint profiles_username_format
    check (username ~ '^[a-z0-9_]{3,20}$'),
  constraint profiles_display_name_length
    check (char_length(btrim(display_name)) between 1 and 50)
);

-- Ensure column exists if table was already created previously
alter table public.profiles
  add column if not exists is_profile_discoverable boolean not null default true;
alter table public.profiles
  add column if not exists bio text not null default '';
alter table public.profiles
  add column if not exists status_text text not null default '';
alter table public.profiles
  add column if not exists status_color text not null default '#0D9488';
alter table public.profiles
  add column if not exists status_created_at timestamptz;

-- Exact / prefix lookups (availability check)
create index if not exists profiles_username_idx
  on public.profiles (username);

-- Fast ILIKE '%query%' search
create index if not exists profiles_username_trgm_idx
  on public.profiles using gin (username extensions.gin_trgm_ops);


-- =============================================================================
-- 2) CONVERSATIONS (1-on-1 AND Groups)
-- =============================================================================
create table if not exists public.conversations (
  id                      uuid        primary key default gen_random_uuid(),
  user1_id                uuid        not null,
  user2_id                uuid        not null,
  last_message            text        not null default '',
  last_message_type       text        not null default 'text',
  last_message_sender_id  uuid,
  last_message_at         timestamptz not null default now(),
  created_at              timestamptz not null default now(),

  -- Group chat columns (backwards-compatible with 1-on-1 rows)
  is_group                boolean     not null default false,
  group_name              text        not null default '',
  group_description       text        not null default '',
  group_avatar_url        text,
  group_owner_id          uuid,
  group_admins            text[]      not null default '{}',
  group_members           text[]      not null default '{}',
  only_admins_can_send    boolean     not null default false,
  only_admins_can_edit    boolean     not null default true,
  group_invite_code       text,

  constraint conversations_user1_id_fkey
    foreign key (user1_id) references public.profiles (id) on delete cascade,
  constraint conversations_user2_id_fkey
    foreign key (user2_id) references public.profiles (id) on delete cascade,
  constraint conversations_last_message_sender_id_fkey
    foreign key (last_message_sender_id) references public.profiles (id) on delete set null,

  constraint conversations_last_message_type_check
    check (last_message_type in ('text', 'audio'))
);

-- Ensure group columns exist if table was already created previously
alter table public.conversations add column if not exists is_group boolean not null default false;
alter table public.conversations add column if not exists group_name text not null default '';
alter table public.conversations add column if not exists group_description text not null default '';
alter table public.conversations add column if not exists group_avatar_url text;
alter table public.conversations add column if not exists group_owner_id uuid;
alter table public.conversations add column if not exists group_admins text[] not null default '{}';
alter table public.conversations add column if not exists group_members text[] not null default '{}';
alter table public.conversations add column if not exists only_admins_can_send boolean not null default false;
alter table public.conversations add column if not exists only_admins_can_edit boolean not null default true;
alter table public.conversations add column if not exists group_invite_code text;

-- Drop strict 1-on-1 distinct check so group rows can also use owner id if needed
alter table public.conversations drop constraint if exists conversations_distinct_users;
drop index if exists conversations_unique_pair_idx;
create unique index if not exists conversations_unique_pair_idx
  on public.conversations (least(user1_id, user2_id), greatest(user1_id, user2_id))
  where is_group = false;

create index if not exists conversations_user1_idx
  on public.conversations (user1_id);
create index if not exists conversations_user2_idx
  on public.conversations (user2_id);
create index if not exists conversations_last_message_at_idx
  on public.conversations (last_message_at desc);


-- =============================================================================
-- 3) MESSAGES
-- =============================================================================
create table if not exists public.messages (
  id               uuid        primary key default gen_random_uuid(),
  conversation_id  uuid        not null
                               references public.conversations (id) on delete cascade,
  sender_id        uuid        not null
                               references public.profiles (id) on delete cascade,
  message_type     text        not null default 'text',
  content          text,
  media_url        text,
  audio_duration   integer     not null default 0,
  is_read          boolean     not null default false,
  created_at       timestamptz not null default now(),

  constraint messages_type_check
    check (message_type in ('text', 'audio')),
  constraint messages_payload_check
    check (
      (message_type = 'text'  and content   is not null and char_length(btrim(content)) > 0)
      or
      (message_type = 'audio' and media_url is not null)
    ),
  constraint messages_audio_duration_check
    check (audio_duration >= 0)
);

create index if not exists messages_conversation_created_idx
  on public.messages (conversation_id, created_at);
create index if not exists messages_unread_idx
  on public.messages (conversation_id, is_read)
  where is_read = false;


-- =============================================================================
-- 4) HELPER FUNCTION (used by RLS)
--    SECURITY DEFINER avoids recursive RLS evaluation on conversations.
-- =============================================================================
create or replace function public.is_conversation_participant(conv_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.conversations c
    where c.id = conv_id
      and (
        c.user1_id = auth.uid()
        or c.user2_id = auth.uid()
        or (c.is_group = true and auth.uid()::text = any(c.group_members))
      )
  );
$$;

revoke all on function public.is_conversation_participant(uuid) from public;
grant execute on function public.is_conversation_participant(uuid) to authenticated;


-- =============================================================================
-- 5) GUARD TRIGGERS (protect immutable columns on UPDATE)
-- =============================================================================

-- conversations: participants may only change the "last_message_*" columns
create or replace function public.conversations_guard_update()
returns trigger
language plpgsql
as $$
begin
  if new.user1_id   <> old.user1_id
  or new.user2_id   <> old.user2_id
  or new.created_at <> old.created_at then
    raise exception 'conversation participants are immutable';
  end if;
  return new;
end;
$$;

drop trigger if exists conversations_guard_update_trg on public.conversations;
create trigger conversations_guard_update_trg
  before update on public.conversations
  for each row execute function public.conversations_guard_update();

-- messages: only "is_read" can be changed after insert
create or replace function public.messages_guard_update()
returns trigger
language plpgsql
as $$
begin
  if new.conversation_id <> old.conversation_id
  or new.sender_id       <> old.sender_id
  or new.message_type    <> old.message_type
  or new.content         is distinct from old.content
  or new.media_url       is distinct from old.media_url
  or new.audio_duration  <> old.audio_duration
  or new.created_at      <> old.created_at then
    raise exception 'only is_read can be updated on messages';
  end if;
  return new;
end;
$$;

drop trigger if exists messages_guard_update_trg on public.messages;
create trigger messages_guard_update_trg
  before update on public.messages
  for each row execute function public.messages_guard_update();


-- =============================================================================
-- 6) ROW LEVEL SECURITY
-- =============================================================================
alter table public.profiles      enable row level security;
alter table public.conversations enable row level security;
alter table public.messages      enable row level security;

-- ---------- profiles ----------
drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
  on public.profiles for select
  to authenticated
  using (true);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  to authenticated
  with check (
    auth.uid() = id
    and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ---------- conversations ----------
drop policy if exists "conversations_select_participant" on public.conversations;
create policy "conversations_select_participant"
  on public.conversations for select
  to authenticated
  using (
    auth.uid() = user1_id
    or auth.uid() = user2_id
    or (is_group = true and auth.uid()::text = any(group_members))
  );

drop policy if exists "conversations_insert_participant" on public.conversations;
create policy "conversations_insert_participant"
  on public.conversations for insert
  to authenticated
  with check (
    auth.uid() = user1_id
    or auth.uid() = user2_id
    or (is_group = true and auth.uid()::text = any(group_members))
  );

drop policy if exists "conversations_update_participant" on public.conversations;
create policy "conversations_update_participant"
  on public.conversations for update
  to authenticated
  using (
    auth.uid() = user1_id
    or auth.uid() = user2_id
    or (is_group = true and auth.uid()::text = any(group_members))
  )
  with check (
    auth.uid() = user1_id
    or auth.uid() = user2_id
    or (is_group = true and auth.uid()::text = any(group_members))
  );

drop policy if exists "conversations_delete_participant" on public.conversations;
create policy "conversations_delete_participant"
  on public.conversations for delete
  to authenticated
  using (
    auth.uid() = user1_id
    or auth.uid() = user2_id
    or (is_group = true and auth.uid() = group_owner_id)
  );

-- ---------- messages ----------
drop policy if exists "messages_select_participant" on public.messages;
create policy "messages_select_participant"
  on public.messages for select
  to authenticated
  using (public.is_conversation_participant(conversation_id));

drop policy if exists "messages_insert_sender" on public.messages;
create policy "messages_insert_sender"
  on public.messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_conversation_participant(conversation_id)
  );

drop policy if exists "messages_delete_sender" on public.messages;
create policy "messages_delete_sender"
  on public.messages for delete
  to authenticated
  using (
    sender_id = auth.uid()
    and public.is_conversation_participant(conversation_id)
  );

-- Only the RECEIVER can mark a message as read
drop policy if exists "messages_update_receiver" on public.messages;
create policy "messages_update_receiver"
  on public.messages for update
  to authenticated
  using (
    sender_id <> auth.uid()
    and public.is_conversation_participant(conversation_id)
  )
  with check (
    sender_id <> auth.uid()
    and public.is_conversation_participant(conversation_id)
  );


-- =============================================================================
-- 7) REALTIME
-- =============================================================================
-- Full row images so UPDATE/DELETE events carry every column (needed for filters)
alter table public.profiles      replica identity full;
alter table public.conversations replica identity full;
alter table public.messages      replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'conversations'
  ) then
    alter publication supabase_realtime add table public.conversations;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;


-- =============================================================================
-- 8) STORAGE — public buckets: voice-notes, avatars
-- =============================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('voice-notes', 'voice-notes', true, 10485760,  -- 10 MB
   array['audio/mp4', 'audio/m4a', 'audio/x-m4a', 'audio/aac', 'audio/mpeg']),
  ('avatars',     'avatars',     true, 5242880,   -- 5 MB
   array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Everyone (anon + authenticated) can READ both buckets
drop policy if exists "atme_public_read" on storage.objects;
create policy "atme_public_read"
  on storage.objects for select
  to public
  using (bucket_id in ('voice-notes', 'avatars'));

-- Authenticated users can UPLOAD voice notes
-- path inside bucket: {conversation_id}/{timestamp}.m4a
drop policy if exists "atme_voice_notes_insert" on storage.objects;
create policy "atme_voice_notes_insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'voice-notes');

-- Authenticated users can UPLOAD avatars
-- path inside bucket: {user_id}/{file_name}
drop policy if exists "atme_avatars_insert" on storage.objects;
create policy "atme_avatars_insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'avatars');

-- Owners can replace (upsert) / delete their own uploaded files
drop policy if exists "atme_owner_update" on storage.objects;
create policy "atme_owner_update"
  on storage.objects for update
  to authenticated
  using (bucket_id in ('voice-notes', 'avatars') and owner_id = auth.uid()::text)
  with check (bucket_id in ('voice-notes', 'avatars') and owner_id = auth.uid()::text);

drop policy if exists "atme_owner_delete" on storage.objects;
create policy "atme_owner_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id in ('voice-notes', 'avatars') and owner_id = auth.uid()::text);

-- =============================================================================
--  END OF SCHEMA
-- =============================================================================
