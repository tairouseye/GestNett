-- 013 — Catalogue de rubriques de dépenses géré par l'app + dépenses générales.
-- On retire la contrainte CHECK figée sur `type` (l'enum Dart fait foi).
alter table public.expenses drop constraint if exists expenses_type_check;

-- market_id est déjà nullable (dépenses générales non rattachées à un marché).
