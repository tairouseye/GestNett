-- 020 — Colonne telephone2 manquante sur company_settings (dérive schéma↔code).
-- Appliqué en prod le 2026-07-01 (via connecteur Supabase).
--
-- Le modèle CompanySettings.toMap() envoie 'telephone2', mais la colonne
-- n'existait dans aucune migration → PostgREST rejetait tout INSERT/UPDATE
-- (« column telephone2 does not exist ») → impossible d'enregistrer la fiche
-- société (dont le logo) → les factures PDF retombaient sur le logo par défaut.

alter table public.company_settings
  add column if not exists telephone2 text;
