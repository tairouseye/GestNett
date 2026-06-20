-- 009 — Adresse et photo de l'employé.
alter table public.employes
  add column if not exists adresse   text,
  add column if not exists photo_url text;
