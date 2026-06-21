-- 012 — Date d'échéance de paiement sur les factures.
alter table public.invoices
  add column if not exists date_echeance date;
