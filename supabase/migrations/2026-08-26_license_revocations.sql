-- Faza 3 (Sistem de Revocare Licente) — ruleaza MANUAL in Supabase SQL
-- Editor (Project > SQL Editor > New query), o singura data. Claude NU are
-- acces la acest proiect Supabase, deci scriptul trebuie rulat de Cristi.
--
-- Design: tabelul brut `license_revocations` NU e citit direct de anon
-- (ar expune machine_id-urile TUTUROR clientilor revocati catre orice
-- client care asculta) — anon poate DOAR apela functia
-- `is_license_revoked(machine_id, product_id)`, care intoarce STRICT
-- true/false pentru o singura pereche, niciodata lista intreaga.
-- service_role (Furnizor, GDCPluginManagerFurnizor/SupabaseAdminConfig.swift)
-- ocoleste RLS si poate scrie/citi/sterge direct in tabel.

create table if not exists public.license_revocations (
  id bigint generated always as identity primary key,
  machine_id text not null,
  product_id text not null,
  revoked_at timestamptz not null default now(),
  reason text
);

create unique index if not exists license_revocations_machine_product_idx
  on public.license_revocations (machine_id, product_id);

alter table public.license_revocations enable row level security;
-- Fara nicio policy pentru `anon`/`authenticated` — tabelul e complet
-- inaccesibil direct prin PostgREST cu cheia anon. Doar service_role
-- (care ocoleste RLS) si functia SECURITY DEFINER de mai jos il pot citi.

create or replace function public.is_license_revoked(p_machine_id text, p_product_id text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.license_revocations
    where machine_id = p_machine_id and product_id = p_product_id
  );
$$;

-- Permite oricui (clientii, cu cheia anon) sa apeleze DOAR aceasta functie,
-- niciodata sa citeasca tabelul brut.
grant execute on function public.is_license_revoked(text, text) to anon;
