-- 007 — Repère « à valoriser » (note d'évaluation excellente), symétrique à a_suivre.
alter table public.employes
  add column if not exists a_valoriser boolean not null default false;
