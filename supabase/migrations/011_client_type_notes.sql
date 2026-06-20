-- 011 — Type (particulier/entreprise) et notes sur les clients.
alter table public.clients
  add column if not exists type  text check (type is null or type in ('particulier', 'entreprise')),
  add column if not exists notes text;
