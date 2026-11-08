-- File Vault: encrypted vaults shared across devices.
--
-- The server only ever sees ciphertext (.fva bytes, base64-encoded) and each
-- vault's marker (PBKDF2 salt + password hash). Passwords and plaintext never
-- leave the device. Row-level security limits every row to its owner.

create table public.vaults (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 200),
  salt text not null,
  password_hash text not null,
  auto_backup_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  unique (owner_id, name)
);

create table public.vault_files (
  id uuid primary key default gen_random_uuid(),
  vault_id uuid not null references public.vaults (id) on delete cascade,
  owner_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 255),
  -- Encrypted file bytes, base64.
  content text not null,
  size integer generated always as (octet_length(decode(content, 'base64'))) stored,
  -- Bumped on every content change; clients send it back to detect
  -- concurrent edits from another device.
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (vault_id, name)
);

create index vault_files_owner_id_idx on public.vault_files (owner_id);

-- Server-controlled version/timestamps; vault and owner can't be changed.
create function public.vault_files_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.id := old.id;
  new.vault_id := old.vault_id;
  new.owner_id := old.owner_id;
  new.created_at := old.created_at;
  if new.content is distinct from old.content then
    new.version := old.version + 1;
    new.updated_at := now();
  else
    new.version := old.version;
    new.updated_at := old.updated_at;
  end if;
  return new;
end;
$$;

create trigger vault_files_before_update
before update on public.vault_files
for each row execute function public.vault_files_before_update();

create function public.vault_files_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.version := 1;
  new.created_at := now();
  new.updated_at := now();
  return new;
end;
$$;

create trigger vault_files_before_insert
before insert on public.vault_files
for each row execute function public.vault_files_before_insert();

alter table public.vaults enable row level security;
alter table public.vault_files enable row level security;

create policy "Owners manage their vaults"
on public.vaults for all to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

create policy "Owners manage files in their vaults"
on public.vault_files for all to authenticated
using (owner_id = (select auth.uid()))
with check (
  owner_id = (select auth.uid())
  and exists (
    select 1 from public.vaults v
    where v.id = vault_id and v.owner_id = (select auth.uid())
  )
);

revoke all on public.vaults, public.vault_files from anon;
grant select, insert, update, delete on public.vaults, public.vault_files
  to authenticated;
