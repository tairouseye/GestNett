-- 008 — Ajoute le niveau « gestion » (gestionnaires, sommet de hiérarchie)
-- à la catégorie des employés.
alter table public.employes drop constraint if exists employes_categorie_check;
alter table public.employes
  add constraint employes_categorie_check
  check (categorie is null or categorie in ('supervision', 'terrain', 'gestion'));
