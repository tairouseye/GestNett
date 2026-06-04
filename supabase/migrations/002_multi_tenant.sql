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
