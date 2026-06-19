-- 005 — Suivi RH des employés : hiérarchie N+1 + visite médicale de démarrage.
alter table public.employes
  add column if not exists superviseur_id     uuid references public.employes(id) on delete set null,
  add column if not exists visite_medicale_le date;   -- date effectuée (null = non faite)

create index if not exists idx_employes_superviseur on public.employes(superviseur_id);
