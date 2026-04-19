-- FlowDay Supabase Schema
-- Run this in your Supabase project's SQL Editor (Database → SQL Editor → New query).
-- All tables are scoped to the authenticated user via Row Level Security (RLS).

-- ─────────────────────────────────────────
-- Extensions
-- ─────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ─────────────────────────────────────────
-- profiles
-- Mirrors FDUser / AuthManager. One row per auth.users entry.
-- ─────────────────────────────────────────
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  name        text not null default '',
  email       text not null default '',
  avatar_url  text,
  provider    text not null default 'apple', -- apple | google | email
  created_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can read own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

-- Auto-create profile on sign-up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ─────────────────────────────────────────
-- projects
-- Mirrors FDProject. Unlimited per user (unlike Todoist free tier).
-- ─────────────────────────────────────────
create table if not exists public.projects (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  name        text not null,
  color_hex   text not null default '#D4713B',
  icon_name   text,
  sort_order  integer not null default 0,
  is_archived boolean not null default false,
  is_favorite boolean not null default false,
  sections    jsonb not null default '[]', -- [string]
  created_at  timestamptz not null default now(),
  modified_at timestamptz not null default now()
);

alter table public.projects enable row level security;

create policy "Users can manage own projects"
  on public.projects for all
  using (auth.uid() = user_id);

-- ─────────────────────────────────────────
-- tasks
-- Mirrors FDTask. priority: 1=urgent, 2=high, 3=medium, 4=none
-- ─────────────────────────────────────────
create table if not exists public.tasks (
  id                  uuid primary key default uuid_generate_v4(),
  user_id             uuid not null references auth.users (id) on delete cascade,
  project_id          uuid references public.projects (id) on delete set null,
  title               text not null,
  notes               text not null default '',
  start_date          timestamptz,
  due_date            timestamptz,
  scheduled_time      timestamptz,
  estimated_minutes   integer,
  priority            integer not null default 4 check (priority between 1 and 4),
  labels              jsonb not null default '[]',   -- [string]
  section             text,                          -- name matching an entry in projects.sections
  sort_order          integer not null default 0,
  is_completed        boolean not null default false,
  completed_at        timestamptz,
  is_deleted          boolean not null default false,
  deleted_at          timestamptz,
  recurrence_rule     text,
  ai_suggested_time   timestamptz,
  cognitive_load      integer,
  created_at          timestamptz not null default now(),
  modified_at         timestamptz not null default now()
);

alter table public.tasks enable row level security;

create policy "Users can manage own tasks"
  on public.tasks for all
  using (auth.uid() = user_id);

create index if not exists tasks_user_id_idx on public.tasks (user_id);
create index if not exists tasks_due_date_idx on public.tasks (user_id, due_date) where not is_deleted;
create index if not exists tasks_scheduled_idx on public.tasks (user_id, scheduled_time) where not is_deleted;

-- ─────────────────────────────────────────
-- subtasks
-- Mirrors FDSubtask.
-- ─────────────────────────────────────────
create table if not exists public.subtasks (
  id                uuid primary key default uuid_generate_v4(),
  user_id           uuid not null references auth.users (id) on delete cascade,
  task_id           uuid not null references public.tasks (id) on delete cascade,
  title             text not null,
  is_completed      boolean not null default false,
  completed_at      timestamptz,
  sort_order        integer not null default 0,
  estimated_minutes integer,
  created_at        timestamptz not null default now()
);

alter table public.subtasks enable row level security;

create policy "Users can manage own subtasks"
  on public.subtasks for all
  using (auth.uid() = user_id);

-- ─────────────────────────────────────────
-- templates
-- AI-generated templates saved by the user.
-- tasks_json holds the list of task titles + priorities the AI produced.
-- ─────────────────────────────────────────
create table if not exists public.templates (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  name        text not null,
  description text not null default '',
  icon        text not null default 'wand.and.stars',
  color_hex   text not null default '#D4713B',
  prompt      text not null default '',  -- the original user prompt that generated this
  tasks_json  jsonb not null default '[]', -- [{ title, priority, estimatedMinutes }]
  created_at  timestamptz not null default now()
);

alter table public.templates enable row level security;

create policy "Users can manage own templates"
  on public.templates for all
  using (auth.uid() = user_id);

-- ─────────────────────────────────────────
-- task_completions
-- Append-only log — one row each time a task is completed.
-- Enables streak tracking, productivity stats, and future ML.
-- ─────────────────────────────────────────
create table if not exists public.task_completions (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  task_id      uuid not null references public.tasks (id) on delete cascade,
  task_title   text not null,  -- denormalized snapshot so stats survive task deletion
  completed_at timestamptz not null default now(),
  energy_level text,           -- 'high' | 'normal' | 'low' at time of completion
  project_id   uuid references public.projects (id) on delete set null
);

alter table public.task_completions enable row level security;

create policy "Users can read and insert own completions"
  on public.task_completions for all
  using (auth.uid() = user_id);

create index if not exists task_completions_user_date_idx
  on public.task_completions (user_id, completed_at desc);
