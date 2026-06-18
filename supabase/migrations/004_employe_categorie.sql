-- 004 — Catégorie d'emploi (supervision / terrain) sur les employés.
-- Appliqué en prod le 2026-06-18. Le métier reste dans la colonne `poste`.
alter table public.employes
  add column if not exists categorie text
  check (categorie is null or categorie in ('supervision', 'terrain'));
