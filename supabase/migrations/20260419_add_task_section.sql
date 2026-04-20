-- 20260419_add_task_section.sql
-- Adds the `section` column to public.tasks so tasks can be grouped under
-- named sections within a project (e.g. "Backlog", "In Progress", "Done").
-- FDProject.sections already holds the list of section names; this column
-- associates a task with one of them by name.
--
-- Safe to run multiple times.

alter table public.tasks
  add column if not exists section text;

create index if not exists tasks_project_section_idx
  on public.tasks (project_id, section) where not is_deleted;
