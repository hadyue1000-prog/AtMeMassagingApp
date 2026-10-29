-- =============================================================================
--  AtMe (@Me) — Supabase Database Migration
--  Fixes:
--    1) Groups not appearing for other members + Group messages pending
--    2) Statuses (حالات الواتساب) not appearing for other users
--
--  HOW TO RUN:
--    1. Open your Supabase Dashboard: https://supabase.com/dashboard/project/hnspdxdhebwvhkzfulir
--    2. Navigate to: SQL Editor (from the left menu)
--    3. Click "New query", paste this entire script, and click "Run" (or Ctrl+Enter).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) CONVERSATIONS: Add columns FIRST so subsequent indexes can reference them
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- 2) CONVERSATIONS: Allow user2_id to be NULL & drop old 1-on-1 constraints
-- -----------------------------------------------------------------------------
alter table public.conversations alter column user2_id drop not null;
alter table public.conversations drop constraint if exists conversations_distinct_users;
alter table public.conversations drop constraint if exists conversations_unique_users;
alter table public.conversations drop constraint if exists conversations_user1_id_user2_id_key;
drop index if exists conversations_unique_pair_idx;

-- Ensure unique index only applies to 1-on-1 chats (now is_group is guaranteed to exist)
create unique index if not exists conversations_unique_pair_idx
  on public.conversations (least(user1_id, user2_id), greatest(user1_id, user2_id))
  where is_group = false;

-- -----------------------------------------------------------------------------
-- 3) PROFILES: Status & Bio columns
-- -----------------------------------------------------------------------------
alter table public.profiles add column if not exists is_profile_discoverable boolean not null default true;
alter table public.profiles add column if not exists bio text not null default '';
alter table public.profiles add column if not exists status_text text not null default '';
alter table public.profiles add column if not exists status_color text not null default '#123D91';
alter table public.profiles add column if not exists status_created_at timestamptz;

-- -----------------------------------------------------------------------------
-- 4) HELPER FUNCTION: is_conversation_participant
--    Supports 1-on-1 AND Group members / owner
-- -----------------------------------------------------------------------------
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
        or (c.user2_id is not null and c.user2_id = auth.uid())
        or (
          c.is_group = true
          and (
            c.group_owner_id = auth.uid()
            or (c.group_members is not null and auth.uid()::text = any(c.group_members))
          )
        )
      )
  );
$$;

revoke all on function public.is_conversation_participant(uuid) from public;
grant execute on function public.is_conversation_participant(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 5) GUARD TRIGGER: conversations_guard_update
--    Allows group meta updates while keeping user1_id immutable
-- -----------------------------------------------------------------------------
create or replace function public.conversations_guard_update()
returns trigger
language plpgsql
as $$
begin
  if new.user1_id <> old.user1_id
  or (new.user2_id is distinct from old.user2_id)
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

-- -----------------------------------------------------------------------------
-- 6) ROW LEVEL SECURITY: Conversations
-- -----------------------------------------------------------------------------
alter table public.conversations enable row level security;

drop policy if exists "conversations_select_participant" on public.conversations;
create policy "conversations_select_participant"
  on public.conversations for select
  to authenticated
  using (
    auth.uid() = user1_id
    or (user2_id is not null and auth.uid() = user2_id)
    or (
      is_group = true
      and (
        group_owner_id = auth.uid()
        or (group_members is not null and auth.uid()::text = any(group_members))
      )
    )
  );

drop policy if exists "conversations_insert_participant" on public.conversations;
create policy "conversations_insert_participant"
  on public.conversations for insert
  to authenticated
  with check (
    auth.uid() = user1_id
    or (user2_id is not null and auth.uid() = user2_id)
    or (
      is_group = true
      and (
        group_owner_id = auth.uid()
        or (group_members is not null and auth.uid()::text = any(group_members))
      )
    )
  );

drop policy if exists "conversations_update_participant" on public.conversations;
create policy "conversations_update_participant"
  on public.conversations for update
  to authenticated
  using (
    auth.uid() = user1_id
    or (user2_id is not null and auth.uid() = user2_id)
    or (
      is_group = true
      and (
        group_owner_id = auth.uid()
        or (group_members is not null and auth.uid()::text = any(group_members))
      )
    )
  )
  with check (
    auth.uid() = user1_id
    or (user2_id is not null and auth.uid() = user2_id)
    or (
      is_group = true
      and (
        group_owner_id = auth.uid()
        or (group_members is not null and auth.uid()::text = any(group_members))
      )
    )
  );

drop policy if exists "conversations_delete_participant" on public.conversations;
create policy "conversations_delete_participant"
  on public.conversations for delete
  to authenticated
  using (
    auth.uid() = user1_id
    or (user2_id is not null and auth.uid() = user2_id)
    or (is_group = true and auth.uid() = group_owner_id)
  );

-- -----------------------------------------------------------------------------
-- 7) ROW LEVEL SECURITY: Messages
-- -----------------------------------------------------------------------------
alter table public.messages enable row level security;

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

-- -----------------------------------------------------------------------------
-- 8) REALTIME REPLICATION
-- -----------------------------------------------------------------------------
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
