-- #####################################################################
-- ##  ⚠️  DANGER — SCRIPT DESTRUCTIF — NE PAS EXÉCUTER PAR INADVERTANCE ##
-- ##                                                                   ##
-- ##  Commence par `DROP SCHEMA public CASCADE` : EFFACE TOUTES LES     ##
-- ##  DONNÉES de la base (clients, marchés, factures, paiements, RH…).  ##
-- ##  À n'utiliser QUE pour reconstruire une base VIDE ou après une     ##
-- ##  perte totale, sur un projet dont on a VÉRIFIÉ qu'il est le bon.   ##
-- ##  Ce n'est PAS une migration : ne jamais le ranger dans migrations/.##
-- #####################################################################
--
-- =====================================================================
--  GesPro — RECONSTRUCTION de la structure (projet dksowmyytsiubnnbmyfo)
--  1) Reset public  2) 001+002  3) employes+affectations (absentes des
--  migrations)  4) migrations 003→016  5) backfill profils
--  Recrée la STRUCTURE (données perdues). auth.users + Storage intacts.
-- =====================================================================

drop schema if exists public cascade;
create schema public;
grant usage on schema public to anon, authenticated, service_role;
grant all on all tables    in schema public to anon, authenticated, service_role;
grant all on all routines  in schema public to anon, authenticated, service_role;
grant all on all sequences in schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables    to anon, authenticated, service_role;
alter default privileges in schema public grant all on routines  to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;

-- ========================= migrations/001_initial_schema.sql =========================
-- ============================================================
-- CleanGest Sénégal — Schéma initial Supabase
-- Exécuter dans l'éditeur SQL du dashboard Supabase
-- ============================================================

-- Extension pour UUID
create extension if not exists "pgcrypto";

-- ============================================================
-- TABLE : profiles
-- ============================================================
create table if not exists public.profiles (
  id          uuid primary key references auth.users on delete cascade,
  email       text,
  nom         text not null default '',
  role        text not null default 'gestionnaire'
                check (role in ('admin', 'gestionnaire')),
  created_at  timestamptz not null default now()
);

-- Créer automatiquement un profil à l'inscription
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, email, nom, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'nom', ''),
    coalesce(new.raw_user_meta_data->>'role', 'gestionnaire')
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- TABLE : clients
-- ============================================================
create table if not exists public.clients (
  id          uuid primary key default gen_random_uuid(),
  nom         text not null,
  contact     text,
  telephone   text,
  email       text,
  adresse     text,
  ninea       text,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);

-- ============================================================
-- TABLE : markets
-- ============================================================
create table if not exists public.markets (
  id             uuid primary key default gen_random_uuid(),
  numero         text unique not null,
  client_id      uuid not null references public.clients(id) on delete cascade,
  date_debut     date,
  date_fin       date,
  description    text,
  montant_total  numeric(12,0) not null default 0,
  statut         text not null default 'en_attente'
                   check (statut in ('en_attente', 'en_cours', 'termine', 'suspendu')),
  created_at     timestamptz not null default now()
);

-- ============================================================
-- TABLE : invoices
-- ============================================================
create table if not exists public.invoices (
  id           uuid primary key default gen_random_uuid(),
  numero       text unique not null,
  market_id    uuid references public.markets(id) on delete set null,
  client_id    uuid not null references public.clients(id) on delete cascade,
  date         date not null default current_date,
  montant_ht   numeric(12,0) not null default 0,
  tva_pct      numeric(5,2) not null default 18,
  total_ttc    numeric(12,0) not null default 0,
  statut       text not null default 'brouillon'
                 check (statut in ('brouillon', 'emise', 'payee_partiel', 'payee', 'annulee')),
  pdf_url      text,
  created_at   timestamptz not null default now()
);

-- ============================================================
-- TABLE : payments
-- ============================================================
create table if not exists public.payments (
  id           uuid primary key default gen_random_uuid(),
  invoice_id   uuid not null references public.invoices(id) on delete cascade,
  montant      numeric(12,0) not null,
  date         date not null default current_date,
  type         text not null default 'partiel'
                 check (type in ('totalite', 'acompte', 'partiel')),
  notes        text,
  created_at   timestamptz not null default now()
);

-- ============================================================
-- TABLE : expenses
-- ============================================================
create table if not exists public.expenses (
  id                uuid primary key default gen_random_uuid(),
  market_id         uuid not null references public.markets(id) on delete cascade,
  type              text not null default 'divers'
                      check (type in ('salaires','produits','transport','carburant','materiel','divers')),
  montant           numeric(12,0) not null,
  description       text,
  justificatif_url  text,
  date              date not null default current_date,
  created_at        timestamptz not null default now()
);

-- ============================================================
-- TABLE : notifications
-- ============================================================
create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references public.profiles(id) on delete cascade,
  type        text not null,
  message     text not null,
  lu          boolean not null default false,
  created_at  timestamptz not null default now()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles      enable row level security;
alter table public.clients        enable row level security;
alter table public.markets        enable row level security;
alter table public.invoices       enable row level security;
alter table public.payments       enable row level security;
alter table public.expenses       enable row level security;
alter table public.notifications  enable row level security;

-- Supprimer les policies existantes avant recréation
drop policy if exists "profiles_own"   on public.profiles;
drop policy if exists "clients_auth"   on public.clients;
drop policy if exists "markets_auth"   on public.markets;
drop policy if exists "invoices_auth"  on public.invoices;
drop policy if exists "payments_auth"  on public.payments;
drop policy if exists "expenses_auth"  on public.expenses;
drop policy if exists "notifs_own"     on public.notifications;

-- Profils : chaque user voit et modifie uniquement son propre profil
create policy "profiles_own" on public.profiles
  for all using (auth.uid() = id);

-- Tables métier : tout utilisateur authentifié peut lire/écrire
-- (à affiner par organisation en phase 2)
create policy "clients_auth" on public.clients
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

create policy "markets_auth" on public.markets
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

create policy "invoices_auth" on public.invoices
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

create policy "payments_auth" on public.payments
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

create policy "expenses_auth" on public.expenses
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

create policy "notifs_own" on public.notifications
  for all using (auth.uid() = user_id);

-- ============================================================
-- STORAGE BUCKETS
-- (créer manuellement dans Dashboard > Storage)
-- logos, signatures, justificatifs, pdfs
-- ============================================================

-- ============================================================
-- DONNÉES DE TEST
-- ============================================================
-- Insérer via l'app après la première connexion admin.
-- Ou décommenter pour tester :

/*
insert into public.clients (nom, telephone, adresse) values
  ('Clinique Cap-Vert', '33 825 00 00', 'Fann, Dakar'),
  ('Société Teranga BTP', '77 456 78 90', 'Plateau, Dakar'),
  ('Ambassade du Japon', '33 869 00 00', 'Almadies, Dakar');
*/


-- ========================= migrations/002_multi_tenant.sql =========================
-- ============================================================
-- 002_multi_tenant.sql — Isolation des données par utilisateur
-- ============================================================

-- 1. Ajouter created_by aux tables existantes
-- ------------------------------------------------------------
ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.markets
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;

-- 2. Remplir created_by pour les données existantes (1 seul user pour l'instant)
-- Remplace le UUID ci-dessous par ton user_id (visible dans Supabase → Authentication)
-- UPDATE public.clients  SET created_by = 'TON-USER-UUID-ICI' WHERE created_by IS NULL;
-- UPDATE public.markets  SET created_by = 'TON-USER-UUID-ICI' WHERE created_by IS NULL;
-- UPDATE public.invoices SET created_by = 'TON-USER-UUID-ICI' WHERE created_by IS NULL;
-- UPDATE public.payments SET created_by = 'TON-USER-UUID-ICI' WHERE created_by IS NULL;
-- UPDATE public.expenses SET created_by = 'TON-USER-UUID-ICI' WHERE created_by IS NULL;

-- 3. Table company_settings (une ligne par utilisateur)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.company_settings (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  company_name text NOT NULL DEFAULT '',
  slogan       text,
  description  text,
  adresse      text,
  telephone    text,
  telephone2   text,
  email        text,
  logo_url     text,
  signature_url text,
  devise       text DEFAULT 'FCFA',
  created_at   timestamptz DEFAULT now(),
  updated_at   timestamptz DEFAULT now()
);

ALTER TABLE public.company_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "settings_owner" ON public.company_settings
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 4. Remplacer les RLS par filtrage owner
-- ------------------------------------------------------------

-- Clients
DROP POLICY IF EXISTS "clients_auth"    ON public.clients;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.clients;
CREATE POLICY "clients_owner" ON public.clients
  FOR ALL USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

-- Markets
DROP POLICY IF EXISTS "markets_auth"    ON public.markets;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.markets;
CREATE POLICY "markets_owner" ON public.markets
  FOR ALL USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

-- Invoices
DROP POLICY IF EXISTS "invoices_auth"   ON public.invoices;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.invoices;
CREATE POLICY "invoices_owner" ON public.invoices
  FOR ALL USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

-- Payments (hérite de l'isolation via la facture)
DROP POLICY IF EXISTS "payments_auth"   ON public.payments;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.payments;
CREATE POLICY "payments_owner" ON public.payments
  FOR ALL USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

-- Expenses
DROP POLICY IF EXISTS "expenses_auth"   ON public.expenses;
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.expenses;
CREATE POLICY "expenses_owner" ON public.expenses
  FOR ALL USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

-- 5. Trigger updated_at sur company_settings
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_company_settings_updated_at ON public.company_settings;
CREATE TRIGGER trg_company_settings_updated_at
  BEFORE UPDATE ON public.company_settings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ========================= tables manquantes (employes, affectations) =========================
create table if not exists public.employes (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references auth.users(id) on delete set null,
  nom text not null default '', prenom text, poste text, telephone text,
  salaire_mensuel numeric not null default 0, part_salariale numeric not null default 0,
  part_patronale numeric not null default 0, frais_gestion_type text not null default 'montant',
  frais_gestion_montant numeric not null default 0, frais_gestion_pct numeric not null default 0,
  matricule text, date_embauche date,
  statut text not null default 'actif' check (statut in ('actif','inactif')),
  notes text, created_at timestamptz not null default now()
);
alter table public.employes enable row level security;
create table if not exists public.affectations (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references auth.users(id) on delete set null,
  employe_id uuid references public.employes(id) on delete cascade,
  market_id uuid references public.markets(id) on delete cascade,
  date_debut date not null default current_date, date_fin date,
  created_at timestamptz not null default now()
);
alter table public.affectations enable row level security;

-- ========================= migrations/003_security_perf_hardening.sql =========================
-- 003 — Durcissement sécurité & performance (audit v3.7.1)
-- Appliqué en prod le 2026-06-18.

-- #3 : la fonction n'est utile que via le trigger on_auth_user_created.
-- Retirer le droit d'exécution direct via l'API REST (RPC).
revoke execute on function public.handle_new_user() from anon, authenticated, public;

-- #5 : remplacer auth.uid() par (select auth.uid()) dans les politiques RLS
-- pour éviter la réévaluation par ligne (perf à l'échelle). USING = WITH CHECK.
drop policy if exists profiles_owner on public.profiles;
create policy profiles_owner on public.profiles
  for all using (id = (select auth.uid())) with check (id = (select auth.uid()));

drop policy if exists settings_owner on public.company_settings;
create policy settings_owner on public.company_settings
  for all using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists clients_owner on public.clients;
create policy clients_owner on public.clients
  for all using (created_by = (select auth.uid())) with check (created_by = (select auth.uid()));

drop policy if exists markets_owner on public.markets;
create policy markets_owner on public.markets
  for all using (created_by = (select auth.uid())) with check (created_by = (select auth.uid()));

drop policy if exists invoices_owner on public.invoices;
create policy invoices_owner on public.invoices
  for all using (created_by = (select auth.uid())) with check (created_by = (select auth.uid()));

drop policy if exists payments_owner on public.payments;
create policy payments_owner on public.payments
  for all using (created_by = (select auth.uid())) with check (created_by = (select auth.uid()));

drop policy if exists expenses_owner on public.expenses;
create policy expenses_owner on public.expenses
  for all using (created_by = (select auth.uid())) with check (created_by = (select auth.uid()));

drop policy if exists employes_owner on public.employes;
create policy employes_owner on public.employes
  for all using (created_by = (select auth.uid())) with check (created_by = (select auth.uid()));

drop policy if exists affectations_owner on public.affectations;
create policy affectations_owner on public.affectations
  for all using (created_by = (select auth.uid())) with check (created_by = (select auth.uid()));

-- #6 : index sur les clés étrangères non couvertes.
create index if not exists idx_affectations_created_by on public.affectations(created_by);
create index if not exists idx_affectations_market_id  on public.affectations(market_id);
create index if not exists idx_clients_created_by      on public.clients(created_by);
create index if not exists idx_employes_created_by      on public.employes(created_by);
create index if not exists idx_expenses_created_by      on public.expenses(created_by);
create index if not exists idx_expenses_market_id       on public.expenses(market_id);
create index if not exists idx_invoices_client_id       on public.invoices(client_id);
create index if not exists idx_invoices_created_by      on public.invoices(created_by);
create index if not exists idx_invoices_market_id       on public.invoices(market_id);
create index if not exists idx_markets_client_id        on public.markets(client_id);
create index if not exists idx_markets_created_by       on public.markets(created_by);
create index if not exists idx_payments_created_by      on public.payments(created_by);
create index if not exists idx_payments_invoice_id      on public.payments(invoice_id);


-- ========================= migrations/004_employe_categorie.sql =========================
-- 004 — Catégorie d'emploi (supervision / terrain) sur les employés.
-- Appliqué en prod le 2026-06-18. Le métier reste dans la colonne `poste`.
alter table public.employes
  add column if not exists categorie text
  check (categorie is null or categorie in ('supervision', 'terrain'));


-- ========================= migrations/005_employe_suivi_rh.sql =========================
-- 005 — Suivi RH des employés : hiérarchie N+1 + visite médicale de démarrage.
alter table public.employes
  add column if not exists superviseur_id     uuid references public.employes(id) on delete set null,
  add column if not exists visite_medicale_le date;   -- date effectuée (null = non faite)

create index if not exists idx_employes_superviseur on public.employes(superviseur_id);


-- ========================= migrations/006_evaluations.sql =========================
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


-- ========================= migrations/007_employe_a_valoriser.sql =========================
-- 007 — Repère « à valoriser » (note d'évaluation excellente), symétrique à a_suivre.
alter table public.employes
  add column if not exists a_valoriser boolean not null default false;


-- ========================= migrations/008_categorie_gestion.sql =========================
-- 008 — Ajoute le niveau « gestion » (gestionnaires, sommet de hiérarchie)
-- à la catégorie des employés.
alter table public.employes drop constraint if exists employes_categorie_check;
alter table public.employes
  add constraint employes_categorie_check
  check (categorie is null or categorie in ('supervision', 'terrain', 'gestion'));


-- ========================= migrations/009_employe_adresse_photo.sql =========================
-- 009 — Adresse et photo de l'employé.
alter table public.employes
  add column if not exists adresse   text,
  add column if not exists photo_url text;


-- ========================= migrations/010_employe_documents.sql =========================
-- 010 — Documents rattachés à un employé (CNI, contrat, certificat médical...).
create table if not exists public.employe_documents (
  id          uuid primary key default gen_random_uuid(),
  employe_id  uuid not null references public.employes(id) on delete cascade,
  nom         text not null,
  type        text,            -- 'cni' | 'contrat' | 'certificat_medical' | 'autre'
  url         text not null,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);
create index if not exists idx_employe_documents_employe on public.employe_documents(employe_id);
alter table public.employe_documents enable row level security;
drop policy if exists employe_documents_owner on public.employe_documents;
create policy employe_documents_owner on public.employe_documents
  for all using (created_by = (select auth.uid()))
  with check (created_by = (select auth.uid()));


-- ========================= migrations/011_client_type_notes.sql =========================
-- 011 — Type (particulier/entreprise) et notes sur les clients.
alter table public.clients
  add column if not exists type  text check (type is null or type in ('particulier', 'entreprise')),
  add column if not exists notes text;


-- ========================= migrations/012_invoice_echeance.sql =========================
-- 012 — Date d'échéance de paiement sur les factures.
alter table public.invoices
  add column if not exists date_echeance date;


-- ========================= migrations/013_expenses_types_general.sql =========================
-- 013 — Catalogue de rubriques de dépenses géré par l'app + dépenses générales.
-- On retire la contrainte CHECK figée sur `type` (l'enum Dart fait foi).
alter table public.expenses drop constraint if exists expenses_type_check;

-- market_id est déjà nullable (dépenses générales non rattachées à un marché).


-- ========================= migrations/014_recurrences.sql =========================
-- 014 — Factures récurrentes (contrats mensuels/trimestriels/annuels)
-- Génération déclenchée côté app (pas d'Edge Function). RLS scopée created_by.

create table if not exists public.recurrences (
  id uuid primary key default gen_random_uuid(),
  market_id uuid not null references public.markets(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  montant_ht numeric not null,
  tva_pct numeric not null default 18,
  frequence text not null default 'mensuelle'
    check (frequence in ('mensuelle','trimestrielle','annuelle')),
  jour_du_mois int not null default 1 check (jour_du_mois between 1 and 28),
  type_facture text not null default 'definitive',
  libelle text,
  actif boolean not null default true,
  prochaine_date date not null,
  derniere_generation date,
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid()
);

create index if not exists recurrences_created_by_idx on public.recurrences (created_by);
create index if not exists recurrences_prochaine_date_idx on public.recurrences (prochaine_date);

alter table public.recurrences enable row level security;

drop policy if exists "recurrences_owner" on public.recurrences;
create policy "recurrences_owner" on public.recurrences
  for all using (created_by = auth.uid()) with check (created_by = auth.uid());


-- ========================= migrations/015_employe_visite_requise.sql =========================
-- 015 — Obligation de visite médicale par employé
-- Défaut : requise, sauf cadres (gestion/supervision) dispensés.

alter table public.employes
  add column if not exists visite_medicale_requise boolean not null default true;

-- Backfill : les gestionnaires et superviseurs ne sont pas concernés par défaut.
update public.employes
  set visite_medicale_requise = false
  where categorie in ('gestion', 'supervision');


-- ========================= migrations/016_fix_colonnes_manquantes.sql =========================
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


-- ========================= backfill profils (comptes existants) =========================
insert into public.profiles (id, email, nom, role)
select id, email, coalesce(raw_user_meta_data->>'nom',''), coalesce(raw_user_meta_data->>'role','gestionnaire')
from auth.users on conflict (id) do nothing;
