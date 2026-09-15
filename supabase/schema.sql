-- =====================================================================
-- HIDEX Bible App — Supabase schema
-- =====================================================================
-- Run this against a fresh Supabase project (SQL Editor, or
-- `supabase db push` with this file as a migration). It is written to
-- be re-run safely on an empty database; it is NOT idempotent against a
-- partially-applied version of itself (use Supabase migrations for that
-- once this baseline is in).
--
-- Sections:
--   0. Extensions & helpers
--   1. Profiles & devices
--   2. Groups & membership
--   3. Live quiz
--   4. Reading plans & streaks
--   5. Devotions
--   6. Weekly stories (studies)
--   7. Study manuals
--   8. Treasure hunts & rewards
--   9. Verse pool
--  10. Cron jobs (pg_cron)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Extensions & helpers
-- ---------------------------------------------------------------------
create extension if not exists pgcrypto;   -- gen_random_uuid()
create extension if not exists pg_cron;    -- scheduled jobs
create extension if not exists pg_net;     -- cron -> edge function HTTP calls

-- Generic updated_at trigger
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Short, unambiguous invite codes (no 0/O/1/I) for groups & hunts
create or replace function public.generate_invite_code(len int default 6)
returns text
language plpgsql
as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
  i int;
begin
  for i in 1..len loop
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  end loop;
  return result;
end;
$$;

-- ---------------------------------------------------------------------
-- 1. Profiles & devices
-- ---------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default 'New Believer',
  avatar_url text,
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Auto-create a profile row whenever a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', 'New Believer'));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  fcm_token text not null,
  platform text not null check (platform in ('android', 'ios', 'web')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, fcm_token)
);

create trigger device_tokens_set_updated_at
  before update on public.device_tokens
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- 2. Groups & membership
-- ---------------------------------------------------------------------
create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 80),
  description text,
  invite_code text not null unique default public.generate_invite_code(),
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

create type public.group_role as enum ('owner', 'admin', 'member');

create table public.group_members (
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.group_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create or replace function public.is_group_member(p_group_id uuid, p_user_id uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = p_user_id
  );
$$;

create or replace function public.is_group_admin(p_group_id uuid, p_user_id uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = p_user_id and role in ('owner', 'admin')
  );
$$;

-- Creator is auto-added as owner.
create or replace function public.handle_new_group()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.group_members (group_id, user_id, role)
  values (new.id, new.created_by, 'owner');
  return new;
end;
$$;

create trigger on_group_created
  after insert on public.groups
  for each row execute function public.handle_new_group();

-- Join a group by invite code (validates code server-side; avoids
-- clients needing insert access to group_members directly).
create or replace function public.join_group_by_code(p_invite_code text)
returns public.groups
language plpgsql
security definer set search_path = public
as $$
declare
  v_group public.groups;
begin
  select * into v_group from public.groups where invite_code = upper(p_invite_code);

  if v_group.id is null then
    raise exception 'Invalid invite code';
  end if;

  insert into public.group_members (group_id, user_id, role)
  values (v_group.id, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;

  return v_group;
end;
$$;

-- ---------------------------------------------------------------------
-- 3. Live quiz
-- ---------------------------------------------------------------------
create type public.quiz_status as enum ('scheduled', 'join_open', 'live', 'closed');

create table public.quizzes (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  title text not null,
  starts_at timestamptz not null,
  join_window_seconds int not null default 120 check (join_window_seconds > 0),
  status public.quiz_status not null default 'scheduled',
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

-- join window = [starts_at - join_window_seconds, starts_at)
create or replace function public.quiz_join_opens_at(q public.quizzes)
returns timestamptz
language sql
immutable
as $$
  select q.starts_at - make_interval(secs => q.join_window_seconds);
$$;

create table public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes (id) on delete cascade,
  position int not null,
  question text not null,
  options jsonb not null, -- e.g. ["Option A", "Option B", "Option C", "Option D"]
  correct_option int not null,
  points int not null default 10,
  time_limit_seconds int not null default 20,
  unique (quiz_id, position)
);

create table public.quiz_participants (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  score int not null default 0,
  unique (quiz_id, user_id)
);

create table public.quiz_answers (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes (id) on delete cascade,
  question_id uuid not null references public.quiz_questions (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  selected_option int not null,
  is_correct boolean not null,
  points_awarded int not null default 0,
  response_ms int,
  answered_at timestamptz not null default now(),
  unique (question_id, user_id)
);

-- Public view of questions that never exposes correct_option to clients.
create view public.quiz_questions_public as
  select id, quiz_id, position, question, options, points, time_limit_seconds
  from public.quiz_questions;

-- Server-enforced grading: client never sees correct_option, only the
-- outcome of its own submission. Mirrors the join-window enforcement in
-- the join_quiz edge function.
create or replace function public.submit_quiz_answer(
  p_question_id uuid,
  p_selected_option int,
  p_response_ms int default null
)
returns table (is_correct boolean, points_awarded int)
language plpgsql
security definer set search_path = public
as $$
declare
  v_question public.quiz_questions;
  v_quiz public.quizzes;
  v_is_correct boolean;
  v_points int := 0;
begin
  select * into v_question from public.quiz_questions where id = p_question_id;
  if v_question.id is null then
    raise exception 'Question not found';
  end if;

  select * into v_quiz from public.quizzes where id = v_question.quiz_id;

  if not exists (
    select 1 from public.quiz_participants
    where quiz_id = v_quiz.id and user_id = auth.uid()
  ) then
    raise exception 'Not a participant in this quiz';
  end if;

  if v_quiz.status != 'live' then
    raise exception 'Quiz is not currently live';
  end if;

  v_is_correct := (p_selected_option = v_question.correct_option);
  if v_is_correct then
    v_points := v_question.points;
  end if;

  insert into public.quiz_answers (quiz_id, question_id, user_id, selected_option, is_correct, points_awarded, response_ms)
  values (v_quiz.id, p_question_id, auth.uid(), p_selected_option, v_is_correct, v_points, p_response_ms)
  on conflict (question_id, user_id) do nothing;

  if found then
    update public.quiz_participants
      set score = score + v_points
      where quiz_id = v_quiz.id and user_id = auth.uid();
  end if;

  return query select v_is_correct, v_points;
end;
$$;

-- ---------------------------------------------------------------------
-- 4. Reading plans & streaks
-- ---------------------------------------------------------------------
create table public.reading_plans (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  duration_days int not null check (duration_days > 0),
  cover_image_url text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

create table public.reading_plan_days (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.reading_plans (id) on delete cascade,
  day_number int not null,
  reference text not null,       -- e.g. "John 3:1-21"
  reading_text text,
  reflection text,
  unique (plan_id, day_number)
);

create table public.reading_plan_enrollments (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.reading_plans (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  started_at timestamptz not null default now(),
  unique (plan_id, user_id)
);

create table public.reading_plan_completions (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.reading_plan_enrollments (id) on delete cascade,
  day_number int not null,
  completed_at timestamptz not null default now(),
  unique (enrollment_id, day_number)
);

-- One streak counter per user, spanning all reading-plan activity.
create table public.user_streaks (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  current_streak int not null default 0,
  longest_streak int not null default 0,
  last_activity_date date
);

-- Marks a day complete and updates the user's streak atomically.
create or replace function public.complete_reading_day(
  p_enrollment_id uuid,
  p_day_number int
)
returns public.user_streaks
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid;
  v_today date := (now() at time zone 'utc')::date;
  v_streak public.user_streaks;
begin
  select user_id into v_user_id
  from public.reading_plan_enrollments
  where id = p_enrollment_id;

  if v_user_id is null or v_user_id != auth.uid() then
    raise exception 'Not your enrollment';
  end if;

  insert into public.reading_plan_completions (enrollment_id, day_number)
  values (p_enrollment_id, p_day_number)
  on conflict (enrollment_id, day_number) do nothing;

  insert into public.user_streaks (user_id, current_streak, longest_streak, last_activity_date)
  values (v_user_id, 1, 1, v_today)
  on conflict (user_id) do update set
    current_streak = case
      when public.user_streaks.last_activity_date = v_today then public.user_streaks.current_streak
      when public.user_streaks.last_activity_date = v_today - 1 then public.user_streaks.current_streak + 1
      else 1
    end,
    longest_streak = greatest(
      public.user_streaks.longest_streak,
      case
        when public.user_streaks.last_activity_date = v_today then public.user_streaks.current_streak
        when public.user_streaks.last_activity_date = v_today - 1 then public.user_streaks.current_streak + 1
        else 1
      end
    ),
    last_activity_date = v_today
  returning * into v_streak;

  return v_streak;
end;
$$;

-- ---------------------------------------------------------------------
-- 5. Devotions
-- ---------------------------------------------------------------------
create table public.devotions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  verse_reference text,
  verse_text text,
  author text,
  image_url text,
  published_at timestamptz not null default now(),
  created_by uuid references public.profiles (id)
);

create table public.devotion_likes (
  devotion_id uuid not null references public.devotions (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (devotion_id, user_id)
);

-- ---------------------------------------------------------------------
-- 6. Weekly stories (studies)
-- ---------------------------------------------------------------------
create table public.weekly_stories (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  verse_reference text,
  audio_url text,
  image_url text,
  week_start_date date not null,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  unique (week_start_date)
);

-- ---------------------------------------------------------------------
-- 7. Study manuals
-- ---------------------------------------------------------------------
create table public.study_manuals (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  cover_image_url text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

create table public.study_manual_chapters (
  id uuid primary key default gen_random_uuid(),
  manual_id uuid not null references public.study_manuals (id) on delete cascade,
  chapter_number int not null,
  title text not null,
  content text not null,
  unique (manual_id, chapter_number)
);

create table public.study_manual_progress (
  user_id uuid not null references public.profiles (id) on delete cascade,
  chapter_id uuid not null references public.study_manual_chapters (id) on delete cascade,
  completed_at timestamptz not null default now(),
  primary key (user_id, chapter_id)
);

-- ---------------------------------------------------------------------
-- 8. Treasure hunts & rewards
-- ---------------------------------------------------------------------
create type public.hunt_status as enum ('scheduled', 'active', 'closed');

create table public.treasure_hunts (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  title text not null,
  description text,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status public.hunt_status not null default 'scheduled',
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

-- IMPORTANT: `answer` is intentionally never exposed to clients. It is
-- graded exclusively by the submit_hunt_answer edge function, which
-- runs with the service_role key. Column-level REVOKE below (section
-- "Grants & column privileges") backs this up at the database level in
-- case a future RLS policy on this table is loosened by mistake.
create table public.hunt_tasks (
  id uuid primary key default gen_random_uuid(),
  hunt_id uuid not null references public.treasure_hunts (id) on delete cascade,
  position int not null,
  prompt text not null,
  answer text not null,
  points int not null default 10,
  hint text,
  unique (hunt_id, position)
);

create view public.hunt_tasks_public as
  select id, hunt_id, position, prompt, points, hint
  from public.hunt_tasks;

create table public.hunt_progress (
  id uuid primary key default gen_random_uuid(),
  hunt_id uuid not null references public.treasure_hunts (id) on delete cascade,
  task_id uuid not null references public.hunt_tasks (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  is_correct boolean not null default false,
  attempts int not null default 0,
  submitted_at timestamptz,
  unique (task_id, user_id)
);

create table public.rewards (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title text not null,
  description text,
  points_required int not null check (points_required >= 0),
  created_at timestamptz not null default now()
);

create table public.user_points (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  total_points int not null default 0
);

create table public.user_rewards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  reward_id uuid not null references public.rewards (id) on delete cascade,
  redeemed_at timestamptz not null default now(),
  unique (user_id, reward_id)
);

-- Called only by the submit_hunt_answer edge function (service_role),
-- never directly by clients — this is where points actually get
-- credited, after server-side grading.
create or replace function public.award_hunt_points(p_user_id uuid, p_points int)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.user_points (user_id, total_points)
  values (p_user_id, p_points)
  on conflict (user_id) do update set total_points = public.user_points.total_points + p_points;
end;
$$;

-- ---------------------------------------------------------------------
-- 9. Verse pool
-- ---------------------------------------------------------------------
create table public.verse_pool (
  id uuid primary key default gen_random_uuid(),
  reference text not null,
  text text not null,
  translation text not null default 'KJV',
  tags text[] not null default '{}',
  created_at timestamptz not null default now(),
  unique (reference, translation)
);

-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.device_tokens enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.quizzes enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.quiz_participants enable row level security;
alter table public.quiz_answers enable row level security;
alter table public.reading_plans enable row level security;
alter table public.reading_plan_days enable row level security;
alter table public.reading_plan_enrollments enable row level security;
alter table public.reading_plan_completions enable row level security;
alter table public.user_streaks enable row level security;
alter table public.devotions enable row level security;
alter table public.devotion_likes enable row level security;
alter table public.weekly_stories enable row level security;
alter table public.study_manuals enable row level security;
alter table public.study_manual_chapters enable row level security;
alter table public.study_manual_progress enable row level security;
alter table public.treasure_hunts enable row level security;
alter table public.hunt_tasks enable row level security;
alter table public.hunt_progress enable row level security;
alter table public.rewards enable row level security;
alter table public.user_points enable row level security;
alter table public.user_rewards enable row level security;
alter table public.verse_pool enable row level security;

-- profiles: readable by any signed-in user (needed for group rosters,
-- leaderboards); only the owner can edit their own row.
create policy "profiles_select_all" on public.profiles
  for select to authenticated using (true);
create policy "profiles_update_own" on public.profiles
  for update to authenticated using (id = auth.uid());

-- device_tokens: strictly private to the owning user.
create policy "device_tokens_owner_all" on public.device_tokens
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- groups: visible to members; creation open to any signed-in user;
-- only owner/admin can update; only owner can delete.
create policy "groups_select_member" on public.groups
  for select to authenticated using (public.is_group_member(id, auth.uid()));
create policy "groups_insert_self" on public.groups
  for insert to authenticated with check (created_by = auth.uid());
create policy "groups_update_admin" on public.groups
  for update to authenticated using (public.is_group_admin(id, auth.uid()));
create policy "groups_delete_owner" on public.groups
  for delete to authenticated using (
    exists (select 1 from public.group_members where group_id = id and user_id = auth.uid() and role = 'owner')
  );

-- group_members: visible to fellow members; membership changes go
-- through join_group_by_code() / admin actions, not direct inserts,
-- except a user removing themselves.
create policy "group_members_select_member" on public.group_members
  for select to authenticated using (public.is_group_member(group_id, auth.uid()));
create policy "group_members_leave_self" on public.group_members
  for delete to authenticated using (user_id = auth.uid());
create policy "group_members_admin_manage" on public.group_members
  for update to authenticated using (public.is_group_admin(group_id, auth.uid()));
create policy "group_members_admin_remove" on public.group_members
  for delete to authenticated using (public.is_group_admin(group_id, auth.uid()));

-- quizzes: visible to group members; managed by group admins.
create policy "quizzes_select_member" on public.quizzes
  for select to authenticated using (public.is_group_member(group_id, auth.uid()));
create policy "quizzes_admin_write" on public.quizzes
  for insert to authenticated with check (public.is_group_admin(group_id, auth.uid()));
create policy "quizzes_admin_update" on public.quizzes
  for update to authenticated using (public.is_group_admin(group_id, auth.uid()));
create policy "quizzes_admin_delete" on public.quizzes
  for delete to authenticated using (public.is_group_admin(group_id, auth.uid()));

-- quiz_questions: the base table (with correct_option) is NOT exposed
-- to clients at all — only quiz_questions_public is. Writes are
-- admin-only.
create policy "quiz_questions_admin_all" on public.quiz_questions
  for all to authenticated using (
    exists (select 1 from public.quizzes q where q.id = quiz_id and public.is_group_admin(q.group_id, auth.uid()))
  ) with check (
    exists (select 1 from public.quizzes q where q.id = quiz_id and public.is_group_admin(q.group_id, auth.uid()))
  );

-- quiz_participants: members of the quiz's group can see who has
-- joined; joining is via insert of your own row (join_quiz edge
-- function performs the actual window check before this insert
-- happens, using the service role, but we also keep a defensive RLS
-- check here in case the row is ever inserted through a different
-- path).
create policy "quiz_participants_select_member" on public.quiz_participants
  for select to authenticated using (
    exists (select 1 from public.quizzes q where q.id = quiz_id and public.is_group_member(q.group_id, auth.uid()))
  );
create policy "quiz_participants_insert_self" on public.quiz_participants
  for insert to authenticated with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.quizzes q
      where q.id = quiz_id
        and public.is_group_member(q.group_id, auth.uid())
        and q.status = 'join_open'
        and now() >= public.quiz_join_opens_at(q)
        and now() < q.starts_at
    )
  );

-- quiz_answers: a user can see their own answers; leaderboard reads go
-- through quiz_participants.score instead of this table. All writes go
-- through submit_quiz_answer(), never direct insert.
create policy "quiz_answers_select_own" on public.quiz_answers
  for select to authenticated using (user_id = auth.uid());

-- reading content: readable by all signed-in users; writes admin-only.
create policy "reading_plans_select_all" on public.reading_plans
  for select to authenticated using (true);
create policy "reading_plans_admin_write" on public.reading_plans
  for all to authenticated using (
    exists (select 1 from public.profiles where id = auth.uid() and is_admin)
  ) with check (
    exists (select 1 from public.profiles where id = auth.uid() and is_admin)
  );

create policy "reading_plan_days_select_all" on public.reading_plan_days
  for select to authenticated using (true);
create policy "reading_plan_days_admin_write" on public.reading_plan_days
  for all to authenticated using (
    exists (select 1 from public.profiles where id = auth.uid() and is_admin)
  ) with check (
    exists (select 1 from public.profiles where id = auth.uid() and is_admin)
  );

create policy "reading_plan_enrollments_owner" on public.reading_plan_enrollments
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "reading_plan_completions_owner" on public.reading_plan_completions
  for select to authenticated using (
    exists (select 1 from public.reading_plan_enrollments e where e.id = enrollment_id and e.user_id = auth.uid())
  );
-- inserts happen exclusively through complete_reading_day()

create policy "user_streaks_select_own" on public.user_streaks
  for select to authenticated using (user_id = auth.uid());

-- devotions: readable by all; writes admin-only; likes owned by user.
create policy "devotions_select_all" on public.devotions
  for select to authenticated using (true);
create policy "devotions_admin_write" on public.devotions
  for all to authenticated using (
    exists (select 1 from public.profiles where id = auth.uid() and is_admin)
  ) with check (
    exists (select 1 from public.profiles where id = auth.uid() and is_admin)
  );
create policy "devotion_likes_select_all" on public.devotion_likes
  for select to authenticated using (true);
create policy "devotion_likes_owner" on public.devotion_likes
  for insert to authenticated with check (user_id = auth.uid());
create policy "devotion_likes_owner_delete" on public.devotion_likes
  for delete to authenticated using (user_id = auth.uid());

-- weekly stories & study manuals: readable by all; writes admin-only.
create policy "weekly_stories_select_all" on public.weekly_stories
  for select to authenticated using (true);
create policy "weekly_stories_admin_write" on public.weekly_stories
  for all to authenticated using (
    exists (select 1 from public.profiles where id = auth.uid() and is_admin)
  ) with check (
    exists (select 1 from public.profiles where id = auth.uid() and is_admin)
  );

create policy "study_manuals_select_all" on public.study_manuals
  for select to authenticated using (true);
create policy "study_manuals_admin_write" on public.study_manuals
  for all to authenticated using (
    exists (select 1 from public.profiles where id = auth.uid() and is_admin)
  ) with check (
    exists (select 1 from public.profiles where id = auth.uid() and is_admin)
  );

create policy "study_manual_chapters_select_all" on public.study_manual_chapters
  for select to authenticated using (true);
create policy "study_manual_chapters_admin_write" on public.study_manual_chapters
  for all to authenticated using (
    exists (select 1 from public.profiles where id = auth.uid() and is_admin)
  ) with check (
    exists (select 1 from public.profiles where id = auth.uid() and is_admin)
  );

create policy "study_manual_progress_owner" on public.study_manual_progress
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- treasure hunts: visible to group members; managed by group admins.
create policy "treasure_hunts_select_member" on public.treasure_hunts
  for select to authenticated using (public.is_group_member(group_id, auth.uid()));
create policy "treasure_hunts_admin_write" on public.treasure_hunts
  for all to authenticated using (public.is_group_admin(group_id, auth.uid()))
  with check (public.is_group_admin(group_id, auth.uid()));

-- hunt_tasks base table: admins only (includes the `answer` column).
-- Regular members must use hunt_tasks_public + the submit_hunt_answer
-- edge function; see "Grants & column privileges" below for the
-- column-level lockdown that makes this the only way to read `answer`.
create policy "hunt_tasks_admin_all" on public.hunt_tasks
  for all to authenticated using (
    exists (select 1 from public.treasure_hunts h where h.id = hunt_id and public.is_group_admin(h.group_id, auth.uid()))
  ) with check (
    exists (select 1 from public.treasure_hunts h where h.id = hunt_id and public.is_group_admin(h.group_id, auth.uid()))
  );

create policy "hunt_progress_select_member" on public.hunt_progress
  for select to authenticated using (
    exists (select 1 from public.treasure_hunts h where h.id = hunt_id and public.is_group_member(h.group_id, auth.uid()))
  );
-- inserts/updates happen exclusively through the submit_hunt_answer
-- edge function (service_role), never directly by clients.

create policy "rewards_select_all" on public.rewards
  for select to authenticated using (true);

create policy "user_points_select_own" on public.user_points
  for select to authenticated using (user_id = auth.uid());

create policy "user_rewards_select_own" on public.user_rewards
  for select to authenticated using (user_id = auth.uid());

create policy "verse_pool_select_all" on public.verse_pool
  for select to authenticated using (true);

-- ---------------------------------------------------------------------
-- Grants & column privileges
-- ---------------------------------------------------------------------
-- Views run with the querying role's privileges by default in Postgres
-- 15+ (security_invoker), so grant the public views explicitly and make
-- sure the sensitive base columns stay out of reach for `authenticated`
-- even if a future RLS policy on the base table is loosened.
alter view public.quiz_questions_public set (security_invoker = true);
alter view public.hunt_tasks_public set (security_invoker = true);

grant select on public.quiz_questions_public to authenticated;
grant select on public.hunt_tasks_public to authenticated;

revoke select (correct_option) on public.quiz_questions from authenticated;
revoke select (answer) on public.hunt_tasks from authenticated;

-- ---------------------------------------------------------------------
-- 10. Cron jobs (pg_cron)
-- ---------------------------------------------------------------------
-- Job 1 — every minute: progress quizzes through their lifecycle
-- (scheduled -> join_open -> live -> closed) purely from timestamps, so
-- the client never has to be the source of truth for quiz state.
create or replace function public.cron_advance_quiz_status()
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.quizzes
    set status = 'join_open'
    where status = 'scheduled'
      and now() >= quiz_join_opens_at(quizzes)
      and now() < starts_at;

  update public.quizzes
    set status = 'live'
    where status in ('scheduled', 'join_open')
      and now() >= starts_at;

  -- auto-close a live quiz once every question's time limit has
  -- elapsed since the quiz started
  update public.quizzes q
    set status = 'closed'
    where q.status = 'live'
      and now() >= q.starts_at + make_interval(
        secs => coalesce((select sum(time_limit_seconds) from public.quiz_questions where quiz_id = q.id), 0)
      );
end;
$$;

select cron.schedule(
  'advance-quiz-status',
  '* * * * *',
  $$select public.cron_advance_quiz_status();$$
);

-- Job 2 — daily at 00:15 UTC: break streaks for anyone who didn't log
-- reading-plan activity yesterday (complete_reading_day only ever
-- grows a streak; this is what makes it possible to lose one).
create or replace function public.cron_reset_stale_streaks()
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.user_streaks
    set current_streak = 0
    where current_streak > 0
      and last_activity_date < (now() at time zone 'utc')::date - 1;
end;
$$;

select cron.schedule(
  'reset-stale-streaks',
  '15 0 * * *',
  $$select public.cron_reset_stale_streaks();$$
);

-- Job 3 — every 5 minutes: close treasure hunts past their end time.
create or replace function public.cron_close_expired_hunts()
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.treasure_hunts
    set status = 'closed'
    where status = 'active'
      and now() >= ends_at;

  update public.treasure_hunts
    set status = 'active'
    where status = 'scheduled'
      and now() >= starts_at
      and now() < ends_at;
end;
$$;

select cron.schedule(
  'close-expired-hunts',
  '*/5 * * * *',
  $$select public.cron_close_expired_hunts();$$
);
