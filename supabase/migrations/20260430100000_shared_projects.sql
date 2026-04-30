-- FlowDay — Shared Projects (Todoist-style collaboration)
--
-- Creates three tables, then applies RLS policies after all tables exist.

-- ─────────────────────────────────────────
-- 1. Create all tables first
-- ─────────────────────────────────────────

create table if not exists public.shared_projects (
  id          uuid primary key default gen_random_uuid(),
  project_id  uuid not null,
  owner_id    uuid not null references auth.users(id) on delete cascade,
  name        text not null default '',
  color_hex   text not null default 'D4713B',
  created_at  timestamptz not null default now()
);

create index if not exists shared_projects_owner_idx on public.shared_projects (owner_id);

create table if not exists public.shared_project_members (
  id                  uuid primary key default gen_random_uuid(),
  shared_project_id   uuid not null references public.shared_projects(id) on delete cascade,
  user_id             uuid references auth.users(id) on delete set null,
  email               text not null,
  role                text not null default 'editor',
  invited_at          timestamptz not null default now(),
  accepted_at         timestamptz,
  unique (shared_project_id, email)
);

create index if not exists shared_members_user_idx on public.shared_project_members (user_id);
create index if not exists shared_members_project_idx on public.shared_project_members (shared_project_id);

create table if not exists public.shared_tasks (
  id                  uuid primary key,
  shared_project_id   uuid not null references public.shared_projects(id) on delete cascade,
  created_by          uuid not null references auth.users(id) on delete cascade,
  title               text not null,
  notes               text not null default '',
  start_date          timestamptz,
  due_date            timestamptz,
  scheduled_time      timestamptz,
  estimated_minutes   integer,
  priority            integer not null default 4,
  labels              text[] not null default '{}',
  section             text,
  sort_order          integer not null default 0,
  is_completed        boolean not null default false,
  completed_at        timestamptz,
  completed_by        uuid references auth.users(id) on delete set null,
  is_deleted          boolean not null default false,
  deleted_at          timestamptz,
  recurrence_rule     text,
  cognitive_load      integer,
  created_at          timestamptz not null default now(),
  modified_at         timestamptz not null default now()
);

create index if not exists shared_tasks_project_idx on public.shared_tasks (shared_project_id);

-- ─────────────────────────────────────────
-- 2. Enable RLS on all tables
-- ─────────────────────────────────────────

alter table public.shared_projects enable row level security;
alter table public.shared_project_members enable row level security;
alter table public.shared_tasks enable row level security;

-- ─────────────────────────────────────────
-- 3. Policies (all tables exist now)
-- ─────────────────────────────────────────

-- shared_projects policies
create policy "Owner can read shared project"
  on public.shared_projects for select
  using (auth.uid() = owner_id
         or exists (
           select 1 from public.shared_project_members m
           where m.shared_project_id = id and m.user_id = auth.uid()
         ));

create policy "Owner can manage shared project"
  on public.shared_projects for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- shared_project_members policies
create policy "Members and owner can read membership"
  on public.shared_project_members for select
  using (auth.uid() = user_id
         or exists (
           select 1 from public.shared_projects p
           where p.id = shared_project_id and p.owner_id = auth.uid()
         ));

create policy "Owner can manage membership"
  on public.shared_project_members for all
  using (exists (
           select 1 from public.shared_projects p
           where p.id = shared_project_id and p.owner_id = auth.uid()
         ))
  with check (exists (
           select 1 from public.shared_projects p
           where p.id = shared_project_id and p.owner_id = auth.uid()
         ));

create policy "Member can accept own invite"
  on public.shared_project_members for update
  using (auth.uid() = user_id);

-- shared_tasks policies
create policy "Members can read shared tasks"
  on public.shared_tasks for select
  using (exists (
    select 1
    from public.shared_projects p
    left join public.shared_project_members m
      on m.shared_project_id = p.id and m.user_id = auth.uid()
    where p.id = shared_tasks.shared_project_id
      and (p.owner_id = auth.uid() or m.user_id = auth.uid())
  ));

create policy "Editors and owner can write shared tasks"
  on public.shared_tasks for all
  using (exists (
    select 1
    from public.shared_projects p
    left join public.shared_project_members m
      on m.shared_project_id = p.id and m.user_id = auth.uid()
    where p.id = shared_tasks.shared_project_id
      and (p.owner_id = auth.uid()
           or (m.user_id = auth.uid() and m.role in ('owner','editor')))
  ));

-- ─────────────────────────────────────────
-- 4. Realtime
-- ─────────────────────────────────────────
alter publication supabase_realtime add table public.shared_projects;
alter publication supabase_realtime add table public.shared_project_members;
alter publication supabase_realtime add table public.shared_tasks;
