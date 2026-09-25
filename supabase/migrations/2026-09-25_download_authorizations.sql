-- Audit + rate limit pentru Edge Function `authorize-download` (S1, 2026-09-25).
-- Fără seriale, fără URL-uri emise. Doar service_role (funcția) scrie și citește: RLS activ, nicio politică.
create table if not exists public.download_authorizations (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  product_id text not null,
  path text not null,
  machine_id text not null,
  ip text not null,
  platform text not null,
  client_version text,
  status smallint not null,
  result text not null
);

create index if not exists download_authorizations_machine_time_idx
  on public.download_authorizations (machine_id, created_at desc);
create index if not exists download_authorizations_ip_time_idx
  on public.download_authorizations (ip, created_at desc);

alter table public.download_authorizations enable row level security;
-- Intenționat fără politici: anon/authenticated nu au acces; service_role ocolește RLS.

-- Retenție: rândurile mai vechi de 90 de zile se pot șterge periodic (pg_cron), opțional:
-- delete from public.download_authorizations where created_at < now() - interval '90 days';
