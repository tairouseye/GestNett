-- 006 — Évaluations des employés (superviseur + client) + suivi qualité.

create table if not exists public.evaluations (
  id            uuid primary key default gen_random_uuid(),
  employe_id    uuid not null references public.employes(id) on delete cascade,
  market_id     uuid references public.markets(id) on delete set null,
  type          text not null check (type in ('superviseur', 'client')),
  date          date not null default current_date,
  reponses      jsonb not null default '{}'::jsonb,
  score         numeric(5,2) not null default 0,   -- normalisé /20
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now()
);

create index if not exists idx_evaluations_employe   on public.evaluations(employe_id);
create index if not exists idx_evaluations_created_by on public.evaluations(created_by);

alter table public.evaluations enable row level security;

drop policy if exists evaluations_owner on public.evaluations;
create policy evaluations_owner on public.evaluations
  for all using (created_by = (select auth.uid()))
  with check (created_by = (select auth.uid()));

-- Suivi qualité sur l'employé
alter table public.employes
  add column if not exists a_suivre    boolean not null default false,
  add column if not exists plan_action text;
