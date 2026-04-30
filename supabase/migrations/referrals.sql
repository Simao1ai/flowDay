-- FlowDay — Referral system
--
-- Tracks per-user referral codes and the resulting sign-ups.
--   user_referral_codes — stable, shareable code per user
--   referrals           — one row per invited person (pending → completed)

create extension if not exists "uuid-ossp";

-- ─────────────────────────────────────────
-- user_referral_codes
-- One row per user. Code is generated client-side (8-char base32)
-- and persisted; uniqueness is enforced by the constraint below.
-- ─────────────────────────────────────────
create table if not exists public.user_referral_codes (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  code        text not null unique,
  created_at  timestamptz not null default now()
);

alter table public.user_referral_codes enable row level security;

create policy "Users read their own code"
  on public.user_referral_codes for select
  using (auth.uid() = user_id);

create policy "Users write their own code"
  on public.user_referral_codes for insert
  with check (auth.uid() = user_id);

-- Anonymous lookup by code (used when a referred user signs up and we
-- need to resolve the inviter). Read-only by code.
create policy "Anyone can resolve a code"
  on public.user_referral_codes for select
  using (true);

-- ─────────────────────────────────────────
-- referrals
-- ─────────────────────────────────────────
create table if not exists public.referrals (
  id                uuid primary key default uuid_generate_v4(),
  referrer_id       uuid not null references auth.users(id) on delete cascade,
  referred_email    text,
  referred_user_id  uuid references auth.users(id) on delete set null,
  code              text not null,
  status            text not null default 'pending', -- pending | completed
  created_at        timestamptz not null default now(),
  completed_at      timestamptz
);

create index if not exists referrals_referrer_idx on public.referrals (referrer_id);
create index if not exists referrals_code_idx     on public.referrals (code);

alter table public.referrals enable row level security;

create policy "Users see referrals they sent"
  on public.referrals for select
  using (auth.uid() = referrer_id or auth.uid() = referred_user_id);

create policy "Users insert their own referrals"
  on public.referrals for insert
  with check (auth.uid() = referrer_id);

create policy "Users update referrals they sent"
  on public.referrals for update
  using (auth.uid() = referrer_id);

-- ─────────────────────────────────────────
-- Auto-mark a referral completed when the referred user signs up.
-- Trigger lives on profiles so it fires after handle_new_user().
-- ─────────────────────────────────────────
create or replace function public.complete_referral_on_signup()
returns trigger language plpgsql security definer as $$
declare
  pending_code text;
begin
  pending_code := current_setting('request.jwt.claims', true)::json->>'referral_code';
  if pending_code is null then return new; end if;

  update public.referrals
     set status = 'completed',
         referred_user_id = new.id,
         completed_at = now()
   where code = pending_code
     and status = 'pending';
  return new;
end;
$$;

drop trigger if exists on_profile_created_complete_referral on public.profiles;
create trigger on_profile_created_complete_referral
  after insert on public.profiles
  for each row execute function public.complete_referral_on_signup();
