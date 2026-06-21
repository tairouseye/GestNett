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
