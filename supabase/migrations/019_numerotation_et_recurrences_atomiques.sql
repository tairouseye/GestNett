-- 019 — Fiabilisation anti-course (compte partagé multi-appareils).
-- Appliqué en prod le 2026-06-30 (via connecteur Supabase).
--
-- 1) Numérotation des factures : remplace le `count(*)+1` côté client (course
--    entre appareils + risque de réutilisation d'un numéro après suppression)
--    par un compteur atomique par marché, monotone et jamais réutilisé.
-- 2) Récurrences : claim atomique « une génération par récurrence et par jour »
--    pour empêcher les doublons quand deux appareils ouvrent l'app le même jour.

-- ─────────────────────────── 1) Numérotation factures ───────────────────────────

create table if not exists public.invoice_counters (
  market_id uuid primary key references public.markets(id) on delete cascade,
  last_seq  int  not null default 0
);

-- Table interne : on bloque tout accès direct (les fonctions security definer
-- ci-dessous y accèdent en contournant la RLS).
alter table public.invoice_counters enable row level security;

-- Backfill : repart du nombre de factures déjà émises par marché.
insert into public.invoice_counters (market_id, last_seq)
select market_id, count(*)
from public.invoices
where market_id is not null
group by market_id
on conflict (market_id) do nothing;

-- Renvoie le prochain numéro de séquence (atomique) pour un marché donné.
-- L'UPSERT ... RETURNING garantit l'unicité même sous appels concurrents.
create or replace function public.next_invoice_seq(p_market_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seq int;
begin
  if not exists (
    select 1 from public.markets
    where id = p_market_id and created_by = auth.uid()
  ) then
    raise exception 'Marché introuvable ou non autorisé';
  end if;

  insert into public.invoice_counters (market_id, last_seq)
    values (p_market_id, 1)
  on conflict (market_id)
    do update set last_seq = public.invoice_counters.last_seq + 1
  returning last_seq into v_seq;

  return v_seq;
end;
$$;

revoke all on function public.next_invoice_seq(uuid) from public, anon;
grant execute on function public.next_invoice_seq(uuid) to authenticated;

-- ─────────────────────────── 2) Claim de récurrence ───────────────────────────

-- Marque la récurrence comme « générée aujourd'hui » de façon atomique.
-- Renvoie true si l'appelant a obtenu le claim (donc doit générer), false si
-- un autre appareil l'a déjà fait aujourd'hui.
create or replace function public.claim_recurrence(p_id uuid, p_today date)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_claimed boolean := false;
begin
  update public.recurrences
    set derniere_generation = p_today
  where id = p_id
    and created_by = auth.uid()
    and (derniere_generation is null or derniere_generation < p_today)
  returning true into v_claimed;

  return coalesce(v_claimed, false);
end;
$$;

revoke all on function public.claim_recurrence(uuid, date) from public, anon;
grant execute on function public.claim_recurrence(uuid, date) to authenticated;
