-- 015 — Obligation de visite médicale par employé
-- Défaut : requise, sauf cadres (gestion/supervision) dispensés.

alter table public.employes
  add column if not exists visite_medicale_requise boolean not null default true;

-- Backfill : les gestionnaires et superviseurs ne sont pas concernés par défaut.
update public.employes
  set visite_medicale_requise = false
  where categorie in ('gestion', 'supervision');
