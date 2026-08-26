-- ============================================================
-- ArtVault — Supabase Schema (camelCase columns with double quotes)
-- PostgreSQL lowercases unquoted identifiers, so all camelCase
-- column names MUST be wrapped in double quotes.
-- ============================================================

-- Drop old tables if they exist (clean slate)
drop table if exists public.users cascade;
drop table if exists public.paintings cascade;
drop table if exists public.documents cascade;
drop table if exists public.revoked cascade;
drop table if exists public.role_audit cascade;
drop table if exists public.public_galleries cascade;
drop table if exists public.backups cascade;
drop table if exists public.artists cascade;

-- Enable UUID generation
create extension if not exists "uuid-ossp";

-- -----------------------------------------------------------
-- 1. USERS
-- -----------------------------------------------------------
create table public.users (
  "uid"          text primary key,
  "email"        text not null default '',
  "displayName"  text not null default 'ArtVault User',
  "photoPath"    text not null default '',
  "photoUrl"     text not null default '',
  "bio"          text not null default '',
  "role"         text not null default 'curator',
  "plan"         text not null default 'free',
  "createdAt"    timestamptz not null default now(),
  "lastLogin"    timestamptz not null default now()
);

-- -----------------------------------------------------------
-- 2. PAINTINGS
-- -----------------------------------------------------------
create table public.paintings (
  "id"                text primary key,
  "title"             text not null default 'Untitled',
  "artistId"          text not null default '',
  "artistName"        text not null default 'Unknown',
  "category"          text not null default '',
  "medium"            text not null default '',
  "style"             text not null default '',
  "description"       text not null default '',
  "tags"              jsonb not null default '[]',
  "width"             double precision,
  "height"            double precision,
  "depth"             double precision,
  "dimensionUnit"     text not null default 'cm',
  "weight"            double precision,
  "weightUnit"        text not null default 'kg',
  "price"             double precision,
  "currency"          text not null default 'USD',
  "availability"      text not null default 'Available',
  "location"          text not null default '',
  "coverImagePath"    text not null default '',
  "coverImageUrl"     text not null default '',
  "images"            jsonb not null default '[]',
  "imageUrls"         jsonb not null default '[]',
  "aiHash"            text not null default '',
  "aiTags"            jsonb not null default '[]',
  "dominantColors"    jsonb not null default '[]',
  "brightness"        double precision not null default 0.5,
  "contrast"          double precision not null default 0.5,
  "orientation"       text not null default 'Landscape',
  "complexity"        double precision not null default 0.5,
  "styleConfidence"   text not null default 'Medium',
  "isFavorite"        boolean not null default false,
  "inPublicGallery"   boolean not null default false,
  "isDeleted"         boolean not null default false,
  "needsSync"         boolean not null default true,
  "synced"            boolean not null default false,
  "ownerUid"          text not null default '',
  "dateCreated"       text,
  "createdAt"         timestamptz not null default now(),
  "updatedAt"         timestamptz not null default now()
);

-- -----------------------------------------------------------
-- 3. DOCUMENTS
-- -----------------------------------------------------------
create table public.documents (
  "id"          text primary key,
  "paintingId"  text not null default '',
  "type"        text not null default 'Other',
  "name"        text not null default 'Untitled',
  "localPath"   text not null default '',
  "remoteUrl"   text not null default '',
  "mimeType"    text not null default 'application/octet-stream',
  "sizeBytes"   bigint not null default 0,
  "isDeleted"   boolean not null default false,
  "needsSync"   boolean not null default true,
  "synced"      boolean not null default false,
  "ownerUid"    text not null default '',
  "createdAt"   timestamptz not null default now()
);

-- -----------------------------------------------------------
-- 4. REVOKED (account revocation markers)
-- -----------------------------------------------------------
create table public.revoked (
  "uid"          text primary key,
  "email"        text not null default '',
  "displayName"  text not null default '',
  "role"         text not null default '',
  "revokedAt"    timestamptz not null default now(),
  "byUid"        text not null default '',
  "byEmail"      text not null default ''
);

-- -----------------------------------------------------------
-- 5. ROLE_AUDIT (audit trail)
-- -----------------------------------------------------------
create table public.role_audit (
  "id"         uuid primary key default uuid_generate_v4(),
  "uid"        text not null default '',
  "byUid"      text not null default '',
  "byEmail"    text not null default '',
  "oldRole"    text not null default '',
  "newRole"    text not null default '',
  "at"         timestamptz not null default now()
);

-- -----------------------------------------------------------
-- 6. PUBLIC_GALLERIES
-- -----------------------------------------------------------
create table public.public_galleries (
  "id"          text primary key,
  "ownerUid"    text not null default '',
  "paintings"   jsonb not null default '[]',
  "updatedAt"   timestamptz not null default now()
);

-- -----------------------------------------------------------
-- 7. BACKUPS (cloud backup snapshots)
-- -----------------------------------------------------------
create table public.backups (
  "id"        text primary key,
  "uid"       text not null default '',
  "updatedAt" timestamptz not null default now(),
  "paintings" jsonb not null default '[]',
  "artists"   jsonb not null default '[]',
  "documents" jsonb not null default '[]',
  "settings"  jsonb not null default '{}'
);

-- -----------------------------------------------------------
-- 8. ARTISTS
-- -----------------------------------------------------------
create table public.artists (
  "id"           text primary key,
  "name"         text not null default '',
  "photoPath"    text not null default '',
  "photoUrl"     text not null default '',
  "biography"    text not null default '',
  "nationality"  text not null default '',
  "phone"        text not null default '',
  "email"        text not null default '',
  "website"      text not null default '',
  "instagram"    text not null default '',
  "facebook"     text not null default '',
  "awards"       jsonb not null default '[]',
  "exhibitions"  jsonb not null default '[]',
  "isDeleted"    boolean not null default false,
  "needsSync"    boolean not null default true,
  "synced"       boolean not null default false,
  "ownerUid"     text not null default '',
  "createdAt"    timestamptz not null default now(),
  "updatedAt"    timestamptz not null default now()
);

-- ============================================================
-- Row Level Security Policies
-- ============================================================

-- Users: owner-only access
alter table public.users enable row level security;
create policy users_select on public.users for select using (auth.uid()::text = "uid");
create policy users_insert on public.users for insert with check (auth.uid()::text = "uid");
create policy users_update on public.users for update using (auth.uid()::text = "uid");

-- Paintings: owner-only CRUD
alter table public.paintings enable row level security;
create policy paintings_select on public.paintings for select using (auth.uid()::text = "ownerUid");
create policy paintings_insert on public.paintings for insert with check (auth.uid()::text = "ownerUid");
create policy paintings_update on public.paintings for update using (auth.uid()::text = "ownerUid");
create policy paintings_delete on public.paintings for delete using (auth.uid()::text = "ownerUid");

-- Documents: owner-only CRUD
alter table public.documents enable row level security;
create policy documents_select on public.documents for select using (auth.uid()::text = "ownerUid");
create policy documents_insert on public.documents for insert with check (auth.uid()::text = "ownerUid");
create policy documents_update on public.documents for update using (auth.uid()::text = "ownerUid");
create policy documents_delete on public.documents for delete using (auth.uid()::text = "ownerUid");

-- Revoked: owner-only access
alter table public.revoked enable row level security;
create policy revoked_select on public.revoked for select using (auth.uid()::text = "uid");
create policy revoked_insert on public.revoked for insert with check (auth.uid()::text = "uid");
create policy revoked_update on public.revoked for update using (auth.uid()::text = "uid");

-- Role audit: owner-only read + insert
alter table public.role_audit enable row level security;
create policy role_audit_select on public.role_audit for select using (auth.uid()::text = "uid" or auth.uid()::text = "byUid");
create policy role_audit_insert on public.role_audit for insert with check (auth.uid()::text = "uid" or auth.uid()::text = "byUid");

-- Public galleries: owner-only access
alter table public.public_galleries enable row level security;
create policy galleries_select on public.public_galleries for select using (auth.uid()::text = "ownerUid");
create policy galleries_insert on public.public_galleries for insert with check (auth.uid()::text = "ownerUid");
create policy galleries_update on public.public_galleries for update using (auth.uid()::text = "ownerUid");

-- Backups: owner-only access
alter table public.backups enable row level security;
create policy backups_select on public.backups for select using (auth.uid()::text = "uid");
create policy backups_insert on public.backups for insert with check (auth.uid()::text = "uid");
create policy backups_update on public.backups for update using (auth.uid()::text = "uid");

-- Artists: owner-only CRUD
alter table public.artists enable row level security;
create policy artists_select on public.artists for select using (auth.uid()::text = "ownerUid");
create policy artists_insert on public.artists for insert with check (auth.uid()::text = "ownerUid");
create policy artists_update on public.artists for update using (auth.uid()::text = "ownerUid");
create policy artists_delete on public.artists for delete using (auth.uid()::text = "ownerUid");

-- ============================================================
-- Reload PostgREST schema cache
-- ============================================================
NOTIFY pgrst, 'reload schema';
