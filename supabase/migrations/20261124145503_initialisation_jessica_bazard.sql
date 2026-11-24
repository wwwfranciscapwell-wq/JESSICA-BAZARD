
-- =====================================================
-- JESSICA BAZARD - INITIALISATION DE LA BOUTIQUE
-- =====================================================

create extension if not exists pgcrypto;

-- 1. CATEGORIES
create table public.categories (
    id uuid primary key default gen_random_uuid(),
    name text not null unique,
    slug text not null unique,
    description text,
    image_url text,
    is_active boolean not null default true,
    created_at timestamptz not null default now()
);

-- 2. PRODUITS
create table public.products (
    id uuid primary key default gen_random_uuid(),
    category_id uuid references public.categories(id)
        on delete set null,
    name text not null,
    slug text not null unique,
    description text,
    price numeric(12,2) not null default 0 check (price >= 0),
    old_price numeric(12,2) check (old_price is null or old_price >= 0),
    stock integer not null default 0 check (stock >= 0),
    image_url text,
    images jsonb not null default '[]'::jsonb,
    is_active boolean not null default true,
    is_featured boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- 3. COMMANDES
create table public.orders (
    id uuid primary key default gen_random_uuid(),
    order_number bigint generated always as identity unique,
    customer_name text not null,
    customer_phone text not null,
    customer_address text,
    customer_city text,
    notes text,
    subtotal numeric(12,2) not null default 0,
    delivery_fee numeric(12,2) not null default 0,
    total numeric(12,2) not null default 0,
    status text not null default 'pending'
        check (status in (
            'pending','confirmed','processing',
            'shipped','delivered','cancelled'
        )),
    created_at timestamptz not null default now()
);

-- 4. DETAILS DES COMMANDES
create table public.order_items (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references public.orders(id)
        on delete cascade,
    product_id uuid references public.products(id)
        on delete set null,
    product_name text not null,
    unit_price numeric(12,2) not null check (unit_price >= 0),
    quantity integer not null check (quantity > 0),
    line_total numeric(12,2) not null check (line_total >= 0)
);

-- 5. PARAMETRES DE LA BOUTIQUE
create table public.store_settings (
    id integer primary key default 1 check (id = 1),
    store_name text not null default 'JESSICA BAZARD',
    whatsapp_number text not null default '077617881',
    currency text not null default 'FCFA',
    primary_color text not null default '#123D70',
    secondary_color text not null default '#FFFFFF',
    photo_one text,
    photo_two text,
    updated_at timestamptz not null default now()
);

insert into public.store_settings (id)
values (1)
on conflict (id) do nothing;

-- 6. INDEX
create index products_category_idx
on public.products(category_id);

create index products_active_idx
on public.products(is_active);

create index orders_status_idx
on public.orders(status);

create index orders_created_idx
on public.orders(created_at desc);

create index order_items_order_idx
on public.order_items(order_id);

-- 7. SECURITE RLS
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.store_settings enable row level security;

-- Consultation publique des catégories actives
create policy "Public read active categories"
on public.categories for select
to anon, authenticated
using (is_active = true);

-- Consultation publique des produits actifs
create policy "Public read active products"
on public.products for select
to anon, authenticated
using (is_active = true);

-- Consultation publique des paramètres
create policy "Public read store settings"
on public.store_settings for select
to anon, authenticated
using (true);

-- Les clients peuvent créer une commande
create policy "Public create orders"
on public.orders for insert
to anon, authenticated
with check (
    status = 'pending'
    and subtotal >= 0
    and delivery_fee >= 0
    and total >= 0
);

-- Les clients peuvent créer les lignes de commande
create policy "Public create order items"
on public.order_items for insert
to anon, authenticated
with check (
    quantity > 0
    and unit_price >= 0
    and line_total >= 0
);

-- Administration réservée au rôle service_role.
-- Aucune politique publique de modification n'est créée.

-- 8. STORAGE : PHOTOS ET IMAGES PRODUITS
insert into storage.buckets (id, name, public)
values ('jessica-products', 'jessica-products', true)
on conflict (id) do nothing;

create policy "Public view Jessica product images"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'jessica-products');

-- FIN DE LA MIGRATION
