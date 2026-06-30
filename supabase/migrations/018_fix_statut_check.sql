-- 018 — Aligne la contrainte CHECK de invoices.statut sur le code.
-- Appliqué en prod le 2026-06-30 (via connecteur Supabase).
--
-- Le schéma initial (001) figeait statut ∈ {brouillon, emise, payee, annulee},
-- mais l'app écrit aussi 'payee_partiel' (encaissement partiel / acompte).
-- Dérive schéma↔code : tout encaissement partiel violait la contrainte.
-- On recrée la contrainte avec la valeur manquante.

alter table public.invoices drop constraint if exists invoices_statut_check;
alter table public.invoices
  add constraint invoices_statut_check
  check (statut in ('brouillon', 'emise', 'payee_partiel', 'payee', 'annulee'));
