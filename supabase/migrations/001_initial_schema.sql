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
                 check (statut in ('brouillon', 'emise', 'payee', 'annulee')),
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
