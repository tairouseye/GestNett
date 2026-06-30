-- 017 — Confidentialité du stockage : documents sensibles en buckets privés.
-- Appliqué en prod le 2026-06-30 (via connecteur Supabase).
--
-- Les buckets 'pdfs' (PDF de factures + documents RH : CNI, contrats,
-- certificats médicaux) et 'justificatifs' (reçus de dépenses) contenaient des
-- données personnelles accessibles par simple URL publique. On les passe en
-- PRIVÉ : la lecture repose désormais sur les policies RLS par dossier
-- propriétaire, et l'app génère des URLs signées temporaires (createSignedUrl).
--
-- 'logos' et 'signatures' restent publics (logo/signature embarqués dans les PDF).

-- 1) Buckets en privé
update storage.buckets set public = false where id in ('pdfs', 'justificatifs');

-- 2) Policies de lecture par dossier propriétaire (idempotent : déjà présentes
--    en prod, recréées ici pour fiabiliser un rebuild).
drop policy if exists pdfs_owner_select on storage.objects;
create policy pdfs_owner_select on storage.objects
  for select using (
    bucket_id = 'pdfs' and split_part(name, '/', 1) = (auth.uid())::text
  );

drop policy if exists justificatifs_owner_select on storage.objects;
create policy justificatifs_owner_select on storage.objects
  for select using (
    bucket_id = 'justificatifs' and split_part(name, '/', 1) = (auth.uid())::text
  );
