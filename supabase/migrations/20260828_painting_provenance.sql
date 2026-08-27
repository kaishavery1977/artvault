-- Add provenance, price history and geo for paintings
alter table public.paintings add column if not exists "lat" double precision;
alter table public.paintings add column if not exists "lng" double precision;
alter table public.paintings add column if not exists "provenance" jsonb not null default '[]';
alter table public.paintings add column if not exists "priceHistory" jsonb not null default '[]';

NOTIFY pgrst, 'reload schema';
