-- 016 — Colonnes historiquement créées à la main (absentes des migrations)
-- Détectées par audit schéma↔code le 2026-06-23 (reconstruction post-incident).
-- Ajout idempotent pour fiabiliser tout rebuild futur.

-- invoices : type de facture ('proforma' | 'definitive')
alter table public.invoices
  add column if not exists type_facture text not null default 'definitive';

-- company_settings : informations légales & bancaires de l'entreprise
alter table public.company_settings
  add column if not exists ninea      text,
  add column if not exists rccm       text,
  add column if not exists iban       text,
  add column if not exists nom_banque text,
  add column if not exists pays       text not null default 'Sénégal',
  add column if not exists ville      text not null default 'Dakar';
