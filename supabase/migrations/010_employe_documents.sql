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
