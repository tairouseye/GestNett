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
